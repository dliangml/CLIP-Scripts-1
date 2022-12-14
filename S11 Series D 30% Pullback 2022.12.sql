set max_y1_line = 5000
;

with UAT_table AS (
SELECT 
  a.*
   , EVALUATED_TIMESTAMP as EVALUATED_TIMESTAMP_UTC // use for CLIP_RESULTS_DATA
 FROM EDW_DB.PUBLIC.CLIP_RESULTS_DATA a
-- FROM SANDBOX_DB.USER_TB.CLIP_UAT_RESULTS_DATA a
WHERE 
////  use for CLIP_RESULTS_DATA ////      
    statement_number in (11)
    and to_date(EVALUATED_TIMESTAMP) >= '2022-11-23'  
  
////  use for CLIP_UAT_RESULTS_DATA ////
    // test_id = '94f989e6-7175-4b4e-af7f-c8475738613b'  //select your test ID 
    // and statement_number = 11
)

,clip_simulation_table AS (
SELECT
  account_id
  ,EVALUATED_TIMESTAMP_UTC
  ,CLIP_POLICY_NAME
  ,POST_CLIP_LINE_LIMIT
  ,PRE_CLIP_LINE_LIMIT
  ,POST_CLIP_LINE_LIMIT - PRE_CLIP_LINE_LIMIT as TEST_CLIP_AMOUNT
--           ,D.SCORES__CLIP_MODEL_D1_20220728_SCORE AS Y1_D_SCORE
-- ,CASE
-- WHEN Y1_D_score <= 0.038
-- THEN 1
-- WHEN Y1_D_score <= 0.062
-- THEN 2
-- WHEN Y1_D_score <= 0.081
-- THEN 3
-- WHEN Y1_D_score <= 0.095
-- THEN 4
-- WHEN Y1_D_score <= 0.126
-- THEN 5
-- WHEN Y1_D_score <= 0.172
-- THEN 6
-- WHEN Y1_D_score <= 0.219
-- THEN 7
-- WHEN Y1_D_score <= 0.253
-- THEN 8
-- WHEN Y1_D_score <= 0.272
-- THEN 9
-- WHEN Y1_D_score <= 0.302
-- THEN 10
-- WHEN Y1_D_score <= 0.333
-- THEN 11
-- WHEN Y1_D_score <= 0.363
-- THEN 12
-- WHEN Y1_D_score > 0.363
-- THEN 13
-- ELSE NULL
--           END AS RISKGROUP_DSERIES_Y1
    , clip_risk_group AS RISKGROUP_DSERIES_Y1
  ,decision_data
  ,decision_data:"potential_atp_net_scores" as potential_atp_net_scores
  ,decision_data:"potential_credit_lines" as potential_credit_lines
  ,STATEMENT_NUMBER
  ,decision_data:"never_delinquent__passed"
  ,decision_data:"block_code__passed"  
  ,decision_data:"atp_net_score"
  ,decision_data:"tu_account_review_missing"
  ,decision_data:"application_atp_value"
  ,decision_data:"not_over_limit__passed"
  ,CASE WHEN  
  STATEMENT_NUMBER in (11)  --Less than statement 18
  --Submitted Income / Residence Update more than 12 months ago
 
  AND decision_data:"never_delinquent__passed" = 'true'
  AND decision_data:"block_code__passed" = 'true' --Bankrupt/Deceased/Fraud
 
   AND
   (CASE
   WHEN decision_data:"atp_net_score"::DOUBLE > 0 THEN TRUE
   WHEN decision_data:"atp_net_score" is null AND decision_data:"tu_account_review_missing"::BOOLEAN = 'true' AND decision_data:"application_atp_value"::FLOAT > 0 THEN TRUE
   ELSE FALSE
   END)
 
  --ATP w/ $1,000 dollar CLIP imputed < 0
  AND decision_data:"not_over_limit__passed" = 'true' --Currently Overlimit
  THEN 1
  ELSE 0
  END
  as pass_eligibility
  ,decision_data:"transunion__account_review__fico_08__FICO_08"
  ,CASE 
  WHEN left(decision_data:"transunion__account_review__fico_08__FICO_08",1) = '+' or decision_data:"transunion__account_review__fico_08__FICO_08" like '%null%'
  then 0 
  else decision_data:"transunion__account_review__fico_08__FICO_08"
  end AS FICO_CLEAN
           ,decision_data:"transunion__account_review__vantage_30__VANTAGE_30"::FLOAT AS vantage_30_float
           ,decision_data:"total_revolving_debt_re33s_to_income"::FLOAT AS total_revolving_debt_to_income_float
           ,decision_data:"total_annual_income"::FLOAT AS total_annual_income_float
  ,decision_data:"total_revolving_debt_re33s_to_income"::FLOAT
  ,decision_data:"transunion__account_review__cv_enriched_attributes__RE33S"::FLOAT
  ,decision_data:"non_mortgage_debt_at33b_hi33s_hr33s_to_income"::FLOAT
  ,decision_data:"transunion__account_review__cv_enriched_attributes__BC01S"::FLOAT
  ,decision_data:"transunion__account_review__cv_enriched_attributes__AT01S"::FLOAT
  ,decision_data:"added_revolving_debt_re33s"::FLOAT
  ,case when FICO_CLEAN::INT > 525 then 1 else 0 end  cond1
  ,case when decision_data:"transunion__account_review__vantage_30__VANTAGE_30"::FLOAT > 525 then 1 else 0 end cond2
  , case when decision_data:"total_revolving_debt_re33s_to_income"::FLOAT < .5  then 1 else 0 end cond3
  , case when decision_data:"transunion__account_review__cv_enriched_attributes__RE33S"::FLOAT < 25000  then 1 else 0 end cond4
  , case when decision_data:"non_mortgage_debt_at33b_hi33s_hr33s_to_income"::FLOAT < 1  then 1 else 0 end cond5
  , case when decision_data:"transunion__account_review__cv_enriched_attributes__BC01S"::FLOAT < 40  then 1 else 0 end cond6
  , case when decision_data:"transunion__account_review__cv_enriched_attributes__AT01S"::FLOAT < 80  then 1 else 0 end cond7
  , case when EVALUATED_TIMESTAMP_UTC >= '2021-11-04' then 1 
        when decision_data:"added_revolving_debt_re33s"::FLOAT <= 7500  then 1 else 0 end cond8
  , case when  decision_data:"payment_vacation__passed" = 'false' then 0 else 1 end cond9
  , case when  decision_data:"revolving_debt_velocity_passed" = 'false' then 0 else 1 end cond10 
  ,CASE
  WHEN
  --(case when (decision_data:"transunion__account_review__fico_08__FICO_08" = '+') then 0 else decision_data:"transunion__account_review__fico_08__FICO_08" end) > 525--FICO <= 525 or invalid
  --AND 
  cond1 = 1
  and cond2 = 1
  and cond3 = 1
  and cond4 = 1
  and cond5 = 1
  and cond6 = 1
  and cond7 = 1
  and cond8 = 1
  and cond9 = 1
  and cond10 = 1
  THEN 1
  ELSE 0
  END
  AS account_review_hardcuts
  ,decision_data:"clip_model_c_20210811_risk_group"::INT AS clip_risk_group_c_INT
  ,decision_data:"clip_model_d1_20220728_risk_group":INT AS clip_risk_group_d_INT
  ,decision_data:"average_utilization_3_months"::FLOAT AS average_utilization_3_months_FLOAT
  ,decision_data:"average_purchase_utilization_3_months"::FLOAT AS average_purchase_utilization_3_months
  ,decision_data:"ab_testing_random_number"::FLOAT AS ab_testing_random_number_FLOAT
  ,decision_data:"policy_assignment_random_number"::FLOAT AS policy_assignment_random_number_FLOAT
  ,decision_data:"payment_vacation__passed" AS payment_vacation__passed
  ,decision_data:"statement_3_outcome" AS statement_3_outcome_TEXT
  ,decision_data:"statement_3_test_group" AS statement_3_test_group_TEXT
  ,decision_data:"second_chance_clip"::VARCHAR as second_chance_clip
  ,OUTCOME
  ,TEST_SEGMENT
  ,decision_data:"delinquencies"::INT AS delinquencies_count
  ,decision_data:"min_clip"::BOOLEAN as min_CLIP_flag
  ,decision_data:"TEST_SEGMENT"
  ,decision_data:"clip_risk_group"
  ,decision_data:"ab_testing_random_number"
  FROM
  UAT_table AS A
           --  LEFT JOIN DS_DB.LINE_MGMT.RETROSCORES_D_SERIES_MODEL_BUILD_v2 D ON A.CARD_ID = D.CARD_ID AND A.STATEMENT_NUMBER = D.INTERNAL__FIS_TSYS__STATEMENT_NUM
  WHERE STATEMENT_NUMBER in (11)
  --AND difference <> 0
)

----
,INFO_ATP_NET_SCORES AS (
SELECT 
  A.account_id 
  ,A.EVALUATED_TIMESTAMP_UTC 
  ,TRIM(B.VALUE) AS potential_atp_net_scores
  ,ROW_NUMBER() OVER (PARTITION BY A.account_id , A.EVALUATED_TIMESTAMP_UTC ORDER BY A.EVALUATED_TIMESTAMP_UTC ) R_NUM
FROM  clip_simulation_table  A
, TABLE(SPLIT_TO_TABLE(A.decision_data:"potential_atp_net_scores"::STRING, ',')) B
WHERE
  decision_data:"potential_atp_net_scores"::STRING <> '[]'
)


,INFO_CL AS (
SELECT A.account_id , A.EVALUATED_TIMESTAMP_UTC , TRIM(C.VALUE) AS potential_credit_lines,
ROW_NUMBER() OVER (PARTITION BY A.account_id , A.EVALUATED_TIMESTAMP_UTC ORDER BY A.EVALUATED_TIMESTAMP_UTC) R_NUM
FROM  clip_simulation_table  A, TABLE(SPLIT_TO_TABLE(A.decision_data:"potential_credit_lines"::STRING, ',')) C
WHERE
  decision_data:"potential_atp_net_scores"::STRING <> '[]'
)

,INFO_ATP_CL AS(
SELECT 
A.account_id
,A.EVALUATED_TIMESTAMP_UTC
,A.R_NUM as ATP_ROW
,B.R_NUM as CL_ROW
,REPLACE(REPLACE(potential_atp_net_scores,'[',''),']','')--::FLOAT 
AS potential_atp_net_scores
,REPLACE(REPLACE(potential_credit_lines,'[',''),']','')--::FLOAT 
		AS potential_credit_lines
FROM INFO_ATP_NET_SCORES A 
INNER JOIN INFO_CL B 
ON A.account_id = B.account_id 
		AND A.EVALUATED_TIMESTAMP_UTC= B.EVALUATED_TIMESTAMP_UTC
		AND A.R_NUM=B.R_NUM
WHERE (potential_atp_net_scores IS NOT NULL OR potential_credit_lines IS NOT NULL)
ORDER BY A.account_id, A.R_NUM)


,Info_MAX_CL as(

SELECT account_id,EVALUATED_TIMESTAMP_UTC, MAX( CASE WHEN potential_atp_net_scores>0 THEN  potential_credit_lines ELSE 0 END ) AS potential_credit_lines_max
FROM INFO_ATP_CL

GROUP BY 1,2)

, CL_THRESHOLD as(
SELECT  A.ACCOUNT_ID,
        A.EVALUATED_TIMESTAMP_UTC,
        A.CLIP_POLICY_NAME,
        STATEMENT_NUMBER,
        decision_data,
        CLIP_RISK_GROUP_c_INT,
             RISKGROUP_DSERIES_Y1,
             CLIP_RISK_GROUP_d_INT, 
              A.vantage_30_float,
              A.total_revolving_debt_to_income_float,
              A.total_annual_income_float,
        AVERAGE_UTILIZATION_3_MONTHS_FLOAT,
        average_purchase_utilization_3_months,
        min_CLIP_flag,
        CASE 
            WHEN AVERAGE_UTILIZATION_3_MONTHS_FLOAT <= 0 THEN 'UTIL1'
            WHEN AVERAGE_UTILIZATION_3_MONTHS_FLOAT < 0.1 THEN 'UTIL2'
            WHEN AVERAGE_UTILIZATION_3_MONTHS_FLOAT < 0.3 THEN 'UTIL3'
            WHEN AVERAGE_UTILIZATION_3_MONTHS_FLOAT < 0.5 THEN 'UTIL4'
            WHEN AVERAGE_UTILIZATION_3_MONTHS_FLOAT < 0.8 THEN 'UTIL5'
            ELSE 'UTIL6' END AS UTIL_BAND,
        AB_TESTING_RANDOM_NUMBER_FLOAT,
        POLICY_ASSIGNMENT_RANDOM_NUMBER_FLOAT,
        statement_3_outcome_TEXT,
        statement_3_test_group_TEXT,
        second_chance_clip,
        OUTCOME,
        TEST_SEGMENT,
        pass_eligibility,
        account_review_hardcuts,
        delinquencies_count,
        PRE_CLIP_LINE_LIMIT,
        TEST_CLIP_AMOUNT
FROM    CLIP_SIMULATION_TABLE A

)

, CLIP_FINAL as(
SELECT  A.ACCOUNT_ID,
        A.EVALUATED_TIMESTAMP_UTC,
       // A.CLIP_POLICY_NAME,
        STATEMENT_NUMBER,
--        decision_data,
        CLIP_RISK_GROUP_c_INT as RISKGROUP_CSERIES_Y1,
               RISKGROUP_DSERIES_Y1,
               A.vantage_30_float,
               A.total_revolving_debt_to_income_float,
               A.total_annual_income_float,
        AVERAGE_UTILIZATION_3_MONTHS_FLOAT,
        //average_purchase_utilization_3_months,
        UTIL_BAND,
        min_CLIP_flag,
        //statement_3_outcome_TEXT,
        //statement_3_test_group_TEXT,
        OUTCOME,
        AB_TESTING_RANDOM_NUMBER_FLOAT,
        //POLICY_ASSIGNMENT_RANDOM_NUMBER_FLOAT,
        TEST_SEGMENT,
        pass_eligibility,
        account_review_hardcuts,
        decision_data,
        --decision_data:"delinquencies_in_6_months",
        decision_data:"block_code__passed",
        decision_data:"atp_net_score",
        decision_data:"not_over_limit__passed",
        decision_data:"application_atp_value",
        delinquencies_count,
        PRE_CLIP_LINE_LIMIT,
        TEST_CLIP_AMOUNT,
        potential_credit_lines_max,
        CASE WHEN ($max_y1_line - PRE_CLIP_LINE_LIMIT) > 0 THEN $max_y1_line - PRE_CLIP_LINE_LIMIT ELSE 0 END
            AS MAX_Y1_CLIP_AMOUNT,

        CASE 
            WHEN MAX_Y1_CLIP_AMOUNT = 0 THEN 0  
            when account_review_hardcuts = 0 then 0
           when (second_chance_clip is null or second_chance_clip not ilike '%true%') and pass_eligibility = 0 then 0
            --2nd chance CLIP
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 between 1 and 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.1  THEN 500
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 between 3 and 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.1  THEN 300
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 between 1 and 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.1  THEN 500
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 between 3 and 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.1  THEN 300
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 between 1 and 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.1  THEN 500
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.1  THEN 300
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 between 1 and 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.1  THEN 500
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.1  THEN 300
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 between 1 and 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.1  THEN 500
            when second_chance_clip ilike '%true%' and PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.1  THEN 300
  
                 when pass_eligibility = 0 then 0
  
           --  --incr transactor CLIP (used pre 30% pullback)
           -- WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0.02  THEN 500
           -- WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0.02  THEN 500
           -- WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0.02  THEN 500
           -- WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0.02  THEN 500
           -- WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0.02  THEN 500
           -- WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0.02  THEN 500
  

    -- post 30% pullback transactor CLIP (keeping transactor CLIP Camunda logic from before pullback)
    WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 in (5,6) AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0  THEN 500   
    WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 in (5,6) AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0  THEN 500  
    WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 in (3,4,5,6) AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0  THEN 500 
    WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 in (3,4,5,6) AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND average_purchase_utilization_3_months >= 0.1 AND ab_testing_random_number_FLOAT >= 0  THEN 500 
    
    
    -- BAU policy

    WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 0.8 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0


WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT <= 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0

WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 0 AND PRE_CLIP_LINE_LIMIT <= 1000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
    
    
    WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 0.8 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0


WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT <= 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0

WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 1000 AND PRE_CLIP_LINE_LIMIT <= 2000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
    
    WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 0.8 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0


WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT <= 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0

WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 2000 AND PRE_CLIP_LINE_LIMIT <= 3000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
    
    WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 0.8 THEN 1000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.2 AND ab_testing_random_number_FLOAT < 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.02 AND ab_testing_random_number_FLOAT < 0.52 THEN 2000
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT < 1 THEN 0


WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT <= 1 THEN 500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0.52 AND ab_testing_random_number_FLOAT <= 1 THEN 2500
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 1 AND ab_testing_random_number_FLOAT <= 1 THEN 0

WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 1 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 2 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 3 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.2 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 4 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0.02 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 5 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 6 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 7 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 8 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 9 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 10 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 11 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 12 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT > 0 AND average_utilization_3_months_FLOAT < 0.1 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.1 AND average_utilization_3_months_FLOAT < 0.3 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.3 AND average_utilization_3_months_FLOAT < 0.5 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.5 AND average_utilization_3_months_FLOAT < 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
WHEN PRE_CLIP_LINE_LIMIT > 3000 AND PRE_CLIP_LINE_LIMIT <= 5000 AND RISKGROUP_DSERIES_Y1 = 13 AND average_utilization_3_months_FLOAT >= 0.8 AND ab_testing_random_number_FLOAT >= 0 AND ab_testing_random_number_FLOAT <= 0 THEN 0
    
  ELSE 0 END AS D_series_CLIP_AMOUNT_no_max
    
    , case when MAX_Y1_CLIP_AMOUNT < D_series_CLIP_AMOUNT_no_max then MAX_Y1_CLIP_AMOUNT  ---ensure no CLIP results in line going above Y1 max line
            when D_series_CLIP_AMOUNT_no_max > 0 and (potential_credit_lines_max - pre_clip_line_limit) < D_series_CLIP_AMOUNT_no_max then potential_credit_lines_max - pre_clip_line_limit     ---ensure no CLIP is higher than the max CLIP according to ATP
            else D_series_CLIP_AMOUNT_no_max end as D_series_CLIP_AMOUNT -- using smaller of max potential CLIP and BAU CLIP amount to make sure we don't go over the max Y1 line amount ($5k)

FROM    CL_THRESHOLD A
        LEFT JOIN Info_MAX_CL B ON A.ACCOUNT_ID = B.ACCOUNT_ID AND A.EVALUATED_TIMESTAMP_UTC = B.EVALUATED_TIMESTAMP_UTC
)

, test as (
select a.account_id
, a.statement_number
, a.PRE_CLIP_LINE_LIMIT
, a.RISKGROUP_DSERIES_Y1
,   a.AB_TESTING_RANDOM_NUMBER_FLOAT
, a.TEST_SEGMENT
, a.decision_data:"model_random_number"
, a.pass_eligibility
, a.account_review_hardcuts
,case when util_band ilike '%1%' then '1:<=0%'
        when util_band ilike '%2%' then '2: 0-10%'
        when util_band ilike '%3%' then '3: 10-30%'
        when util_band ilike '%4%' then '4: 30-50%'
        when util_band ilike '%5%' then '5: 50-80%'
        when util_band ilike '%6%' then '6: >80%'
    end as util
    ,case when pre_clip_line_limit <= 1000 then 1000
        when pre_clip_line_limit <= 2000 then 2000
        when pre_clip_line_limit <= 3000 then 3000
        when pre_clip_line_limit > 3000 then 4000
      end as PCL
    , D_SERIES_CLIP_AMOUNT 
    , TEST_CLIP_AMOUNT
    , case when test_clip_amount > 0 then 1 else 0 end as D_CLIP_CNT
    , MAX_Y1_CLIP_AMOUNT 
    , D_series_CLIP_AMOUNT_no_max
    , a.decision_data
FROM    CLIP_FINAL a
-- where D_series_CLIP_AMOUNT <> TEST_CLIP_AMOUNT
    )
    
    
      select  *
      -- count(*), avg(test_clip_amount) 
    from test
    -- where test_clip_amount > 0
   where  pre_clip_line_limit > 3000
;   
 
