alter role authenticator set pgrst.db_schemas = 'public,graphql_public,ssr_ingest';
notify pgrst, 'reload config';
