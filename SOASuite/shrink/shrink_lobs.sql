DECLARE
  CURSOR c_tabs
  IS
    SELECT
      a.owner owner,
      a.table_name table_name,
      a.column_name column_name
    FROM
      all_tab_cols a
    WHERE
      a.owner LIKE 'XX_SOAINFRA'
    AND a.data_type LIKE '%LOB'
    AND EXISTS
      (
        SELECT
          1
        FROM
          all_tables b
        WHERE
          a.owner       =b.owner
        AND a.table_name=b.table_name
      )
  AND EXISTS
    (
      SELECT
        1
      FROM
        dba_lobs l ,
        dba_segments s
      WHERE
        s.segment_name      = l.segment_name
      AND s.owner           = l.owner
      AND s.bytes/1024/1024 > 100
      AND s.owner           =a.owner
      AND l.table_name      =a.table_name
      AND l.column_name     =a.column_name
    )
  ORDER BY
    owner,
    table_name,
    column_name;
  r_prevtab c_tabs%rowtype;
  l_countlobrecs NUMBER;
FUNCTION hasFunctionBasedIndex(
    p_owner      VARCHAR2,
    p_table_name VARCHAR2)
  RETURN VARCHAR2
IS
  l_indexcount NUMBER;
BEGIN
  SELECT
    COUNT(*)
  INTO
    l_indexcount
  FROM
    all_indexes c
  WHERE
    c.table_owner =p_owner
  AND c.table_name=p_table_name
  AND c.index_type LIKE 'FUN%';
  IF l_indexcount>0 THEN
    RETURN 'Y';
  ELSE
    RETURN 'N';
  END IF;
END;
BEGIN
  begin
  execute immediate 'DROP INDEX XX_SOAINFRA.BRDECISIONINSTANCE_INDX5';
  dbms_output.put_line('Index created: XX_SOAINFRA.BRDECISIONINSTANCE_INDX5');
  exception
  when others then
  null;
  end; 
  r_prevtab.owner := NULL;
  FOR r_tabs IN c_tabs
  LOOP
    IF (r_prevtab.owner IS NOT NULL AND
      (
        r_prevtab.owner != r_tabs.owner OR r_prevtab.table_name != r_tabs.table_name
      )
      ) OR r_prevtab.owner IS NULL THEN
      dbms_output.put_line('Processing table: "'||r_tabs.owner||'"."'||r_tabs.table_name||'"');
      IF hasFunctionBasedIndex(r_tabs.owner,r_tabs.table_name) = 'N' THEN
        EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name||'" deallocate unused';
        EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name||'" enable row movement';
        EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name||'" shrink space compact';
        BEGIN
          --below causes lock and sets high water mark
          EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name||'" shrink space';
        EXCEPTION
          --when a lock is present: skip
        WHEN OTHERS THEN
          dbms_output.put_line('Skipping shrink space due to: '||SQLERRM);
        END;
        EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name||'" disable row movement';
      END IF;
      r_prevtab := r_tabs;
    ELSE
      dbms_output.put_line('Table has function based index and cannot be shrinked: "'|| r_tabs.owner||'"."'||r_tabs.table_name||'"');
    END IF;
    dbms_output.put_line('Processing column: "'||r_tabs.owner||'"."'||r_tabs.table_name||'"."'||r_tabs.column_name||'"');
    EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name|| '" modify lob("'||r_tabs.column_name||'") (deallocate unused)';
    --below causes lock
    BEGIN
      EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name ||'" modify lob("'||r_tabs.column_name||'") (freepools 1)';
    EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Skipping freepools: '||SQLERRM);
    END;
    BEGIN
      EXECUTE immediate 'alter table "'||r_tabs.owner||'"."'||r_tabs.table_name ||'" modify lob("'||r_tabs.column_name||'") (shrink space)';
    EXCEPTION
    WHEN OTHERS THEN
      dbms_output.put_line('Skipping shrink space: '||SQLERRM);
    END;
  END LOOP;
  begin
  execute immediate 'CREATE INDEX XX_SOAINFRA.BRDECISIONINSTANCE_INDX5 ON XX_SOAINFRA.BRDECISIONINSTANCE (ECID, "CREATION_TIME" DESC) LOGGING TABLESPACE XX_SOAINFRA NOPARALLEL';
  dbms_output.put_line('Index created: XX_SOAINFRA.BRDECISIONINSTANCE_INDX5');
  exception
  when others then
  null;
  end;
END;
