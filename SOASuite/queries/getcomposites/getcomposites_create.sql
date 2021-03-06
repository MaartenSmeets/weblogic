prompt Create objects

create PACKAGE SOA_UTIL
AS
  FUNCTION GET_AUDIT_TRAIL(
      P_CIKEY NUMBER)
    RETURN CLOB;
  FUNCTION BLOB_TO_CLOB(
      blob_in IN BLOB)
    RETURN CLOB;
  FUNCTION get_str_for_comp_inst(
    p_composite_instance_id IN NUMBER,
    p_searchregexp VARCHAR2,
    p_sensorname VARCHAR2,
    p_recursive VARCHAR2)
    RETURN VARCHAR2;
  FUNCTION GET_AUDIT_TRAIL_BPM(
      P_QUERY_ID NUMBER)
    RETURN CLOB;
  FUNCTION GET_AUDIT_TRAIL_MEDIATOR(
      P_MEDIATOR_INSTANCE_ID NUMBER)
    RETURN CLOB;	

END SOA_UTIL;
/
create PACKAGE BODY SOA_UTIL
AS
FUNCTION blob_to_clob(
    blob_in IN BLOB)
  RETURN CLOB
AS
  v_clob CLOB;
  v_varchar VARCHAR2(32767);
  v_start PLS_INTEGER  := 1;
  v_buffer PLS_INTEGER := 32767;
BEGIN
  DBMS_LOB.CREATETEMPORARY(v_clob, TRUE);
  FOR i IN 1..CEIL(DBMS_LOB.GETLENGTH(blob_in) / v_buffer)
  LOOP
    v_varchar := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(blob_in, v_buffer,
    v_start));
    DBMS_LOB.WRITEAPPEND(v_clob, LENGTH(v_varchar), v_varchar);
    v_start := v_start + v_buffer;
  END LOOP;
  RETURN v_clob;
END blob_to_clob;

FUNCTION GET_AUDIT_TRAIL_BPM(P_QUERY_ID NUMBER) RETURN CLOB
AS
V_AUDIT_BLOB BLOB;
V_AUDIT_CLOB CLOB;
V_CUR_AUDIT SYS_REFCURSOR;

TYPE TP_AUDIT_RECORD IS RECORD(
AUDIT_LOG BLOB
);
TYPE TP_AUDIT_ARRAY IS TABLE OF TP_AUDIT_RECORD;
V_AUDIT_ARRAY TP_AUDIT_ARRAY;
V_AUDIT_COMPLETE BLOB;

V_BUFFER_LENGTH PLS_INTEGER := 32767;
V_BUFFER VARCHAR2(32767);
V_READ_START PLS_INTEGER := 1;
BEGIN

DBMS_LOB.CREATETEMPORARY(V_AUDIT_BLOB, TRUE);
DBMS_LOB.CREATETEMPORARY(V_AUDIT_CLOB, TRUE);
DBMS_LOB.CREATETEMPORARY(V_AUDIT_COMPLETE, TRUE);

OPEN V_CUR_AUDIT FOR 'SELECT AUDIT_LOG FROM BPM_AUDIT_QUERY where QUERY_ID=:query_id AND AUDIT_LOG IS NOT NULL' USING P_QUERY_ID;
FETCH V_CUR_AUDIT BULK COLLECT INTO V_AUDIT_ARRAY;
CLOSE V_CUR_AUDIT;

FOR j IN 1..V_AUDIT_ARRAY.COUNT LOOP

DBMS_LOB.APPEND (V_AUDIT_COMPLETE, UTL_COMPRESS.LZ_UNCOMPRESS(V_AUDIT_BLOB));
DBMS_LOB.CREATETEMPORARY(V_AUDIT_BLOB, TRUE);
DBMS_LOB.APPEND (V_AUDIT_BLOB, V_AUDIT_ARRAY(j).AUDIT_LOG);
END LOOP;

DBMS_LOB.APPEND (V_AUDIT_COMPLETE, UTL_COMPRESS.LZ_UNCOMPRESS(V_AUDIT_BLOB));
V_AUDIT_ARRAY.DELETE;
FOR i IN 1..CEIL(DBMS_LOB.GETLENGTH(V_AUDIT_COMPLETE) / V_BUFFER_LENGTH) LOOP
V_BUFFER := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(V_AUDIT_COMPLETE, V_BUFFER_LENGTH, V_READ_START));
DBMS_LOB.WRITEAPPEND(V_AUDIT_CLOB, LENGTH(V_BUFFER), V_BUFFER);
V_READ_START := V_READ_START + V_BUFFER_LENGTH;
END LOOP;
IF DBMS_LOB.GETLENGTH(V_AUDIT_CLOB) > 0 THEN
RETURN V_AUDIT_CLOB;
ELSE
RETURN NULL;
END IF;
END;

FUNCTION GET_AUDIT_TRAIL_MEDIATOR(P_MEDIATOR_INSTANCE_ID NUMBER) RETURN CLOB
AS
V_AUDIT_BLOB BLOB;
V_AUDIT_CLOB CLOB;
V_CUR_AUDIT SYS_REFCURSOR;

TYPE TP_AUDIT_RECORD IS RECORD(
AUDIT_LOG BLOB
);
TYPE TP_AUDIT_ARRAY IS TABLE OF TP_AUDIT_RECORD;
V_AUDIT_ARRAY TP_AUDIT_ARRAY;
V_AUDIT_COMPLETE BLOB;

V_BUFFER_LENGTH PLS_INTEGER := 32767;
V_BUFFER VARCHAR2(32767);
V_READ_START PLS_INTEGER := 1;
BEGIN

DBMS_LOB.CREATETEMPORARY(V_AUDIT_BLOB, TRUE);
DBMS_LOB.CREATETEMPORARY(V_AUDIT_CLOB, TRUE);
DBMS_LOB.CREATETEMPORARY(V_AUDIT_COMPLETE, TRUE);

OPEN V_CUR_AUDIT FOR 'SELECT mad.document AUDIT_LOG FROM mediator_audit_document mad where mad.instance_id=to_char(:mediator_instance) AND mad.document IS NOT NULL order by mad.instance_id' USING P_MEDIATOR_INSTANCE_ID;
FETCH V_CUR_AUDIT BULK COLLECT INTO V_AUDIT_ARRAY;
CLOSE V_CUR_AUDIT;

FOR j IN 1..V_AUDIT_ARRAY.COUNT LOOP

DBMS_LOB.APPEND (V_AUDIT_COMPLETE, UTL_COMPRESS.LZ_UNCOMPRESS(V_AUDIT_BLOB));
DBMS_LOB.CREATETEMPORARY(V_AUDIT_BLOB, TRUE);
DBMS_LOB.APPEND (V_AUDIT_BLOB, V_AUDIT_ARRAY(j).AUDIT_LOG);
END LOOP;

DBMS_LOB.APPEND (V_AUDIT_COMPLETE, UTL_COMPRESS.LZ_UNCOMPRESS(V_AUDIT_BLOB));
V_AUDIT_ARRAY.DELETE;
FOR i IN 1..CEIL(DBMS_LOB.GETLENGTH(V_AUDIT_COMPLETE) / V_BUFFER_LENGTH) LOOP
V_BUFFER := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(V_AUDIT_COMPLETE, V_BUFFER_LENGTH, V_READ_START));
DBMS_LOB.WRITEAPPEND(V_AUDIT_CLOB, LENGTH(V_BUFFER), V_BUFFER);
V_READ_START := V_READ_START + V_BUFFER_LENGTH;
END LOOP;
IF DBMS_LOB.GETLENGTH(V_AUDIT_CLOB) > 0 THEN
RETURN V_AUDIT_CLOB;
ELSE
RETURN NULL;
END IF;
END;

FUNCTION GET_AUDIT_TRAIL(
    P_CIKEY NUMBER)
  RETURN CLOB
AS
  V_AUDIT_BLOB BLOB;
  V_AUDIT_CLOB CLOB;
  V_CUR_AUDIT SYS_REFCURSOR;
TYPE TP_AUDIT_ARRAY
IS
  TABLE OF BLOB;
  V_AUDIT_ARRAY TP_AUDIT_ARRAY;
  V_BUFFER_LENGTH PLS_INTEGER := 32767;
  V_BUFFER VARCHAR2(32767);
  V_READ_START PLS_INTEGER := 1;
BEGIN
  DBMS_LOB.CREATETEMPORARY(V_AUDIT_BLOB, TRUE);
  DBMS_LOB.CREATETEMPORARY(V_AUDIT_CLOB, TRUE);
  BEGIN
    OPEN V_CUR_AUDIT FOR
    'SELECT LOG FROM AUDIT_TRAIL WHERE CIKEY = :cikey ORDER BY COUNT_ID' USING
    P_CIKEY;
    FETCH
      V_CUR_AUDIT BULK COLLECT
    INTO
      V_AUDIT_ARRAY;
    CLOSE V_CUR_AUDIT;
    FOR j IN 1..V_AUDIT_ARRAY.COUNT
    LOOP
      DBMS_LOB.APPEND (V_AUDIT_BLOB, V_AUDIT_ARRAY(j));
    END LOOP;
    V_AUDIT_ARRAY.DELETE;
    V_AUDIT_BLOB := UTL_COMPRESS.LZ_UNCOMPRESS(V_AUDIT_BLOB);
    FOR i IN 1..CEIL(DBMS_LOB.GETLENGTH(V_AUDIT_BLOB) / V_BUFFER_LENGTH)
    LOOP
      V_BUFFER := UTL_RAW.CAST_TO_VARCHAR2(DBMS_LOB.SUBSTR(V_AUDIT_BLOB,
      V_BUFFER_LENGTH, V_READ_START));
      DBMS_LOB.WRITEAPPEND(V_AUDIT_CLOB, LENGTH(V_BUFFER), V_BUFFER);
      V_READ_START := V_READ_START + V_BUFFER_LENGTH;
    END LOOP;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  RETURN V_AUDIT_CLOB;
END;

FUNCTION get_str_for_comp_inst(
    p_composite_instance_id IN NUMBER,
    p_searchregexp VARCHAR2,
    p_sensorname VARCHAR2,
    p_recursive VARCHAR2)
  RETURN VARCHAR2
AS
  l_searchresult VARCHAR2(256);
BEGIN

  --check title
  BEGIN
    IF p_searchregexp IS NULL THEN
		RAISE_APPLICATION_ERROR(0,'Continue...');
	END IF;
	SELECT
	/*+ use_nl (ci) */
      REGEXP_SUBSTR(ci.title,p_searchregexp)
    INTO
      l_searchresult
    FROM
      composite_instance ci
    WHERE
      ci.id    =p_composite_instance_id;
    IF l_searchresult IS NOT NULL THEN
      --RETURN 'Title: '||l_searchresult;
	  RETURN l_searchresult;
    ELSE
      RAISE_APPLICATION_ERROR(0,'Continue...');
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  
  --check sensors
  BEGIN
    IF p_sensorname IS NULL THEN
		RAISE_APPLICATION_ERROR(0,'Continue...');
	END IF;
	SELECT
	/*+ use_nl (cs) */
      REGEXP_REPLACE (WM_CONCAT (cs.string_value), '([^,]+)(,\1)*(,|$)', '\1\3'
      )
    INTO
      l_searchresult
    FROM
      composite_sensor_value cs
    WHERE
      cs.composite_instance_id = p_composite_instance_id
    AND UPPER (cs.sensor_name) LIKE p_sensorname;
    IF l_searchresult IS NOT NULL THEN
      --RETURN 'Sensor: '||l_searchresult;
	  RETURN l_searchresult;
    ELSE
      RAISE_APPLICATION_ERROR(0,'Continue...');
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  
  --check audit trail
  BEGIN
    IF p_searchregexp IS NULL THEN
		RAISE_APPLICATION_ERROR(0,'Continue...');
	END IF;
    SELECT
      /*+ use_nl (atr ci) */
      REGEXP_REPLACE ( WM_CONCAT ( REGEXP_SUBSTR (GET_AUDIT_TRAIL (atr.cikey),
      p_searchregexp)), '([^,]+)(,\1)*(,|$)', '\1\3')
    INTO
      l_searchresult
    FROM
      audit_trail atr,
      cube_instance ci
    WHERE
      atr.cikey     = ci.cikey
    AND ci.cmpst_id = p_composite_instance_id;
    IF l_searchresult      IS NOT NULL THEN
      --RETURN 'Audit trail: '||l_searchresult;
	  RETURN l_searchresult;
    ELSE
      RAISE_APPLICATION_ERROR(0,'Continue...');
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  
  --check audit details
  BEGIN
    SELECT
      /*+ use_nl (ad ci) */
      REGEXP_REPLACE ( WM_CONCAT ( REGEXP_SUBSTR ( blob_to_clob (
      UTL_COMPRESS.LZ_UNCOMPRESS (ad.bin)), p_searchregexp)),
      '([^,]+)(,\1)*(,|$)', '\1\3')
    INTO
      l_searchresult
    FROM
      audit_details ad,
      cube_instance ci
    WHERE
      ad.cikey      = ci.cikey
    AND ci.cmpst_id = p_composite_instance_id;
    IF l_searchresult      IS NOT NULL THEN
      --RETURN 'Audit details: '||l_searchresult;
	  RETURN l_searchresult;
    ELSE
      RAISE_APPLICATION_ERROR(0,'Continue...');
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
  
  --check audit trail BPM
  BEGIN
    IF p_searchregexp IS NULL THEN
		RAISE_APPLICATION_ERROR(0,'Continue...');
	END IF;
    SELECT
	  /*+ use_nl (baq) */
      REGEXP_REPLACE ( WM_CONCAT ( REGEXP_SUBSTR (GET_AUDIT_TRAIL_BPM (baq.QUERY_ID),
      p_searchregexp)), '([^,]+)(,\1)*(,|$)', '\1\3')
    INTO
      l_searchresult
    FROM
      BPM_AUDIT_QUERY baq
    WHERE
	  baq.composite_instance_id = to_char(p_composite_instance_id) order by baq.QUERY_ID;
    IF l_searchresult      IS NOT NULL THEN
      --RETURN 'Audit trail BPM: '||l_searchresult;
	  RETURN l_searchresult;
    ELSE
      RAISE_APPLICATION_ERROR(0,'Continue...');
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;

  --check audit trail Mediator
  BEGIN
    IF p_searchregexp IS NULL THEN
		RAISE_APPLICATION_ERROR(0,'Continue...');
	END IF;
    SELECT
      /*+ use_nl (mi) */
	  REGEXP_REPLACE ( WM_CONCAT ( REGEXP_SUBSTR (GET_AUDIT_TRAIL_MEDIATOR (mi.id),
      p_searchregexp)), '([^,]+)(,\1)*(,|$)', '\1\3')
    INTO
      l_searchresult
    FROM
      MEDIATOR_INSTANCE mi
    WHERE
	  mi.composite_instance_id = p_composite_instance_id order by mi.id;
    IF l_searchresult      IS NOT NULL THEN
      --RETURN 'Audit trail Mediator: '||l_searchresult;
	  RETURN l_searchresult;
    ELSE
      RAISE_APPLICATION_ERROR(0,'Continue...');
    END IF;
  EXCEPTION
  WHEN OTHERS THEN
    NULL;
  END;
 
  --do all above checks for composites with the same ecid
  IF p_recursive = 'Y' THEN
    BEGIN
      EXECUTE immediate
      'SELECT WM_CONCAT( distinct SOA_UTIL.get_str_for_comp_inst(ci1.id,:1,:2,''N'')) from composite_instance ci1, composite_instance ci2 where ci1.ecid=ci2.ecid and ci1.id != ci2.id and ci2.id=:3'
      INTO l_searchresult USING p_searchregexp,p_sensorname,p_composite_instance_id;
      IF l_searchresult IS NOT NULL THEN
        --RETURN 'ECID: '||l_searchresult;
		RETURN l_searchresult;
      ELSE
        RAISE_APPLICATION_ERROR(0,'Continue...');
      END IF;
    EXCEPTION
    WHEN OTHERS THEN
      NULL;
    END;
  END IF;
  RETURN NULL;
END;
END SOA_UTIL;
/
CREATE INDEX cube_instance_fbcmpstid ON cube_instance
  (
    to_number(cmpst_id),
    cikey
  )
  invisible
/
CREATE INDEX composite_instance_ecidid ON
  composite_instance
  (
    ecid,
    id
  )
  invisible
/
CREATE INDEX mediator_instance_cmpstid ON mediator_instance
  (
    composite_instance_id,
    id
  )
  invisible
/
CREATE INDEX mediator_audit_document_instid ON mediator_audit_document
  (
    instance_id
  )
  invisible
/
