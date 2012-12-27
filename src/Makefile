
DB = chess

PSQL = psql $(DB) -f $< > /dev/null && touch $@

all: .runsql

.runsql: .tables.sql .api.sql
	touch .runsql

.api.sql: .tables.sql

.%.sql : %.sql
	$(PSQL)

data: data.sql
	$(PSQL)

eco: dump_eco.sql
	$(PSQL)


clean:
	rm -f .*.sql .runsql


	
