
DB = chess
LIB_DIR = `pwd`/../../build/lib

PSQL = psql $(DB) -f $< --set pgchess_dir=\'$(LIB_DIR)\' > /dev/null && touch $@

PSQL_DATA = psql $(DB) -f $< --set pgchess_dir=\'$(LIB_DIR)\'

all: .runsql

.runsql: .tables.sql .api.sql
	touch .runsql

.api.sql: .tables.sql

.%.sql : %.sql
	$(PSQL)



data: dump.sql
	$(PSQL_DATA)

eco: dump_eco.sql
	$(PSQL_DATA)

clean:
	rm -f .*.sql .runsql


	
