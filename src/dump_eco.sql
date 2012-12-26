/* Copyright Nate Carson 2012 */

\set ON_ERROR_STOP

set DYNAMIC_LIBRARY_PATH to
    '$libdir'
	    ':/home/muskrat/src/chess/trunk/src/build/lib'
		; load 'libpgchess';

create temp table tmp_game(
	id			integer
	,eco		varchar(4)
	,nick		text
	,variation	text
	,subvar 	integer	
);
	

create temp table tmp_move (
	game_id		integer
	,movenum	integer
	,iswhite	boolean
	,ssquare	square
	,esquare	square
	,subject	char(1)
	,target		char(1)
	,fen		board
	,san		san
);

\copy tmp_game from '../data/eco_fixed.tags.dump';
\copy tmp_move from '../data/eco.moves.dump';


insert into position
	(id)
	select 
		fen 
	from tmp_move
	where not exists (select id from position where fen=id)
	group by fen
;


insert into opening (eco, nick, variation, subvar)
	select
		eco, nick, variation, subvar
	from tmp_game
	where not exists 
	(
		select 1
		from opening 
		where tmp_game.nick = opening.nick
		and tmp_game.variation = opening.variation
		and tmp_game.subvar = opening.subvar
	)
	group by eco, nick, variation, subvar
;


-- We need to find the opening.id's we have just added and put them 
-- into tmp_game so we have a reference for inserting moves.
alter table tmp_game add column opening_id integer;
update tmp_game
	set opening_id = opening.opening_id
	from 
	(
		select tmp_game.id as tmp_game_id, opening.id as opening_id
		from tmp_game
		join opening on 
			tmp_game.nick = opening.nick
			and tmp_game.variation = opening.variation
	) as opening
	where tmp_game.id = opening.tmp_game_id
;


insert into openingmove (opening_id, movenum, iswhite, position_id, move)
	select 
		tmp_game.opening_id
		,tmp_move.movenum
		,tmp_move.iswhite
		,position.id
		,(ssquare::text || esquare::text)::move
	
	from tmp_move
		join tmp_game on tmp_game.id = tmp_move.game_id
		join position on tmp_move.fen = position.id
	
	where not exists
	(
		select 1
		from openingmove
		where 
			openingmove.opening_id = tmp_game.opening_id
			and openingmove.movenum = tmp_move.movenum
			and openingmove.iswhite = tmp_move.iswhite
	)
;

update opening
	set c_move_count = count
	from	
	(
		select opening_id, count(move) from openingmove group by opening_id
	) as t
	where c_move_count is null
	and opening.id = opening_id
;


