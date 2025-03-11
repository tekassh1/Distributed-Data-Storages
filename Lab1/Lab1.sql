DROP FUNCTION IF EXISTS get_files_recursive(directory TEXT);
CREATE FUNCTION get_files_recursive(directory TEXT)
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

DROP PROCEDURE IF EXISTS get_files_meta();
CREATE PROCEDURE get_files_meta()
AS $$
    DECLARE
        file_path TEXT;
        data_dir TEXT;
        file_counter INT := 1;
        file_name TEXT;
        file_meta RECORD;
    BEGIN
        RAISE NOTICE E'\r% % % %', RPAD('No.', 4), RPAD('FILE#', 25), RPAD('MODIFICATION', 24), RPAD('SIZE', 20);
        RAISE NOTICE '---  ------------------------  ----------------------   --------';

        EXECUTE 'SHOW data_directory' INTO data_dir;

        FOR file_path IN SELECT * FROM get_files_recursive(data_dir)
        LOOP
            file_name := split_part(file_path, '/', array_length(string_to_array(file_path, '/'), 1));
            file_meta := pg_stat_file(file_path);
            RAISE NOTICE E'\r% % % %',
                RPAD(file_counter::TEXT, 4),
                RPAD(file_name, 25),
                RPAD(file_meta.modification::TEXT, 24),
                RPAD(file_meta.size::TEXT, 20);

            file_counter := file_counter + 1;
        END LOOP;

        EXCEPTION
            WHEN OTHERS THEN
                RETURN;

    END
$$ LANGUAGE plpgsql;

CALL get_files_meta();

-- SELECT * FROM get_files_recursive('/var/lib/postgresql/16/main');
-- SELECT * FROM pg_stat_file('/var/lib/postgresql/16/main/base/4/1259_vm');