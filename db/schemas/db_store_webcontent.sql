DROP TABLE IF EXISTS result_store;

CREATE TABLE result_store (
    endpoint VARCHAR,
    html text,
    PRIMARY KEY ("endpoint")
);
