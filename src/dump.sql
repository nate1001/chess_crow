/* Copyright Nate Carson 2012 */

\set ON_ERROR_STOP
set client_min_messages=WARNING;

set DYNAMIC_LIBRARY_PATH to
    '$libdir'
	':/home/muskrat/src/chess/trunk/src/build/lib'
	; load 'libpgchess';

create temp table tmp_game(
	id			integer
	,event		text
	,site		text
	,date_		date
	,round		text
	,wplayer 	text
	,bplayer 	text
	,result		gameresult
);
	

create temp table tmp_move (
-- FIXME we need a promotion field for move
-- TODO get rid of fields we do not need
	game_id		integer
	,movenum	integer
	,iswhite	boolean
	,ssquare	square
	,esquare	square
	--,subject	piececlass
	--,target		piececlassempty
	,subject	text
	,target		text
	,fen		board
	,san		san
);

\copy tmp_game from '../data/games.tags.dump';
\copy tmp_move from '../data/games.moves.dump';


insert into position
	(id)
	select 
		fen 
	from tmp_move
	where not exists (select id from position where fen=id)
	group by fen
;


insert into player (nick)
	select p
	from (select wplayer as p from tmp_game union select bplayer as p from tmp_game) as players
	where p not in (select nick from player)
	group by p
;

insert into game (event, site, date_, round, wplayer_id, bplayer_id, result)
	select event, site, date_, round, wp.id as wplayer, bp.id as bplayer, result
	from tmp_game
	join player as bp on bp.nick = tmp_game.bplayer
	join player as wp on wp.nick = tmp_game.wplayer
	where not exists
	(
		select game.id 
		from game
			join player as bp on bp.nick = tmp_game.bplayer
			join player as wp on wp.nick = tmp_game.wplayer
		where
			tmp_game.event = game.event
			and tmp_game.site = game.site
			and tmp_game.date_ = game.date_
			and tmp_game.round = game.round
			and bp.id = game.bplayer_id
			and wp.id = game.wplayer_id
			and tmp_game.result = game.result
	)
	group by event, site, date_, round, wp.id ,bp.id, result
;

-- We need to find the game.id's we have just added and put them into tmp_game so we have a reference for inserting moves.
alter table tmp_game add column game_id integer;
update tmp_game
	set game_id = game.game_id
	from 
	(
		select tmp_game.id as tmp_game_id, game.id as game_id
		from tmp_game
		join player as bp on bp.nick = tmp_game.bplayer
		join player as wp on wp.nick = tmp_game.wplayer
		join game on 
			tmp_game.event = game.event
			and tmp_game.site = game.site
			and tmp_game.date_ = game.date_
			and tmp_game.round = game.round
			and bp.id = game.bplayer_id
			and wp.id = game.wplayer_id
			and tmp_game.result = game.result
	) as game
	where tmp_game.id = game.tmp_game_id
;


insert into gamemove (game_id, movenum, iswhite, position_id, move)
	select 
		tmp_game.game_id
		,tmp_move.movenum
		,tmp_move.iswhite
		,position.id
		,(ssquare::text || esquare)::move
	
	from tmp_move
		join tmp_game on tmp_game.id = tmp_move.game_id
		join position on tmp_move.fen = position.id
	
	where not exists
	(
		select 1
		from gamemove
		where 
			gamemove.game_id = tmp_game.game_id
			and gamemove.movenum = tmp_move.movenum
			and gamemove.iswhite = tmp_move.iswhite
	)
		
;


