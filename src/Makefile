
DB = 'chess'
PSQL = psql $(DB)

all: tables api

tables:
	$(PSQL) -f $@.sql

api: tables
	$(PSQL) -f $@.sql


data:
	$(PSQL) -f dump.sql 

eco:
	$(PSQL) -f dump_eco.sql 


	
