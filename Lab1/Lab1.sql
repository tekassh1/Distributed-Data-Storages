-- SET search_path TO pg_temp;

DROP FUNCTION IF EXISTS pg_temp.get_files_recursive(directory TEXT);
CREATE FUNCTION pg_temp.get_files_recursive(directory TEXT)
RETURNS TABLE(file_name TEXT)
AS $$
    DECLARE
        entry TEXT;
    BEGIN
        FOR entry IN SELECT pg_ls_dir(directory)
        LOOP
            BEGIN
                IF (pg_stat_file(directory || '/' || entry)).isDir THEN
                    RETURN QUERY SELECT * FROM get_files_recursive(directory || '/' || entry);
                ELSE
                    RETURN QUERY SELECT (directory || '/' || entry);
                END IF;

            EXCEPTION
                WHEN OTHERS THEN
                    CONTINUE;
            END;
        END LOOP;

        EXCEPTION
            WHEN OTHERS THEN
                RETURN;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE pg_temp.show_files_meta()
AS $$
DECLARE
    rec record;
BEGIN
    RAISE NOTICE 'No. | FILE# | CREATION_TIME | STATUS | SIZE';
    RAISE NOTICE '----|-------|---------------|--------|------';

    FOR rec IN
        SELECT
            ROW_NUMBER() OVER (ORDER BY c.oid) AS "No.",
            pg_relation_filepath(c.oid) AS "FILE#",
            NULL AS "CREATION_TIME",
            CASE
                WHEN c.relpersistence = 'p' THEN 'PERMANENT'
                WHEN c.relpersistence = 't' THEN 'TEMPORARY'
                WHEN c.relpersistence = 'u' THEN 'UNLOGGED'
                ELSE 'ONLINE'
            END AS "STATUS",
            pg_size_pretty(pg_relation_size(c.oid)) AS "SIZE"
        FROM pg_class c
        WHERE c.relkind IN ('r', 't', 'm') AND c.relfilenode <> 0
        ORDER BY pg_relation_filepath(c.oid)
    LOOP
        RAISE NOTICE '% | % | % | % | %',
            rec."No.", rec."FILE#", rec."CREATION_TIME", rec."STATUS", rec."SIZE";
    END LOOP;
END
$$ LANGUAGE plpgsql;

CALL pg_temp.show_files_meta();


-- SELECT * FROM get_files_recursive('/var/lib/postgresql/16/main');
-- SELECT * FROM pg_stat_file('/var/lib/postgresql/16/main/base/4/1259_vm');