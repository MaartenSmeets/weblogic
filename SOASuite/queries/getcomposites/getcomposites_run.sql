prompt Create report

set termout off heading off feedback off linesize 1000 pagesize 0 trimspool on

rem alter session set sql_trace = true
rem /
alter session set optimizer_use_invisible_indexes = true
/

spool search_composites.lis
SELECT '"' || ci2.id || '",' ||
  '"' || soa_util.get_str_for_comp_inst(ci2.id,'AA\d\d\.\d+','%AAIDENTIFICATION%','Y') || '",' || 
  '"' || REPLACE(REPLACE(REGEXP_SUBSTR(ci2.composite_dn, '/.*?!'),'/',''),'!','') || '",' ||
  '"' || REPLACE(REPLACE(REGEXP_SUBSTR(ci2.composite_dn, '!.*?\*'),'!',''),'*','') || '",' ||
  '"' || extract( DAY FROM sysdate-ci2.created_time) || '",' ||
  '"' || DECODE(ci2.state, '0','Running', '1','Completed', '2','Running with faults', '3','Completed with faults', '4','Running with recovery required', '5','Completed with recovery required', '6','Running with faults and recovery required', '7','Completed with faults and recovery required', '8','Running with suspended', '9','Completed with suspended', '10','Running with faults and suspended', '11','Completed with faults and suspended', '12','Running with recovery required and suspended', '13','Completed with recovery required and suspended', '14','Running with faults, recovery required, and suspended', '15','Completed with faults, recovery required, and suspended', '16','Running with terminated', '17','Completed with terminated', '18','Running with faults and terminated', '19','Completed with faults and terminated', '20','Running with recovery required and terminated', '21','Completed with recovery required and terminated', '22','Running with faults, recovery required, and terminated',
  '23' , 'Completed with faults, recovery required, and terminated', '24','Running with suspended and terminated', '25','Completed with suspended and terminated', '26','Running with faulted, suspended, and terminated', '27','Completed with faulted, suspended, and terminated', '28','Running with recovery required, suspended, and terminated', '29','Completed with recovery required, suspended, and terminated', '30','Running with faulted, recovery required, suspended, and terminated', '31','Completed with faulted, recovery required, suspended, and terminated', '32','Unknown', '64','-','Unknown') || '"'
FROM composite_instance ci2
WHERE ci2.state NOT IN (1,3)
/
spool off

set termout on feedback on
