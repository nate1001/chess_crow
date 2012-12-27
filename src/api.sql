/* Copyright Nate Carson 2012 */

\set ON_ERROR_STOP
SET client_min_messages=WARNING;

--------------------------------------
--	views  ---------------------------
--------------------------------------

drop view if exists view_game cascade;
create view view_game as select
	game.id
	,event
	,site
	,date_
	,round::integer
	,wplayer.nick as white
	,bplayer.nick as black
	,result

	from game
	join player as bplayer on bplayer.id = game.bplayer_id
	join player as wplayer on wplayer.id = game.wplayer_id
	order by date_, round
;


drop view if exists view_gamemove cascade;
create view view_gamemove as select
	gamemove.id
	,game_id
	,movenum
	,iswhite
	,move
	,position_move_san(tofen(position_id), move) as san
	,position_id as board_before
	,toboard(position_make_move(tofen(position_id), move)) as board_after
	--,fiftymove

	from gamemove
;

drop view if exists view_opening cascade;
create view view_opening as select
	opening.id
	,eco
	,opening.nick as opening
	,opening.variation 
	,opening.subvar
	,array_agg(position_move_san(tofen(position_id), move)) as moves

	from (
		select * from openingmove
		order by opening_id, movenum, iswhite desc
	) as openingmove
	join opening on opening_id = opening.id

	group by opening.id, eco, opening, variation, subvar
;

drop view if exists view_openingmove cascade;
create view view_openingmove as select
	openingmove.id
	,opening.eco
	,opening.nick as opening
	,opening.variation 
	,opening.subvar
	,opening.c_move_count
	,movenum
	,iswhite
	,move
	,position_move_san(tofen(position_id), move) as san
	,position_id as board_before
	,toboard(position_make_move(tofen(position_id), move)) as board_after
	--,fiftymove

	from openingmove
	join opening on opening_id = opening.id
;

drop view if exists view_variation cascade;
create view view_variation as 
	select
		-- roll the move_ids into an array so we can have all move transpositions for one position
		count(*)
		position_id
		,array_agg(move) as move
	-- group the last position so we have move transpositions
	from 
	(
		select 
			position_id
			,move
		from gamemove 
		group by move, position_id
	)  as t 
	group by position_id
;




drop view if exists view_positionstat cascade;
create view view_positionstat as
	
	select
	
	round((wins / (wins + losses + draws)::numeric), 2) as white_winr
	,round((losses / (wins + losses + draws)::numeric), 2) as white_loser
	,round((draws/ (wins + losses + draws)::numeric), 2) as drawr
	,wins + losses + draws as total
	,wins
	,losses
	,draws
	,undetermined
	,position_id
	,move
	,position_move_san(tofen(position_id), move) as san
	
	from
	(
		select 
			(sum(case when result = '1-0' then 1 else 0 end)) as wins 
			,(sum(case when result = '0-1' then 1 else 0 end)) as losses
			,(sum(case when result = '1/2-1/2' then 1 else 0 end)) as draws 
			,(sum(case when result = '*' then 1 else 0 end)) as undetermined
			,position_id
			,move as move
		from gamemove 
		join game on gamemove.game_id = game.id 
		group by position_id, move
	) as t 
;



--------------------------------------
--	functions ------------------------
--------------------------------------


-- games()
-- returns all games
create or replace function games() returns setof view_game language sql as
	$$
		select * from view_game;
	$$
;

-- games(player)
-- returns all games of a certain player name
create or replace function games(player text) returns setof view_game language sql as
	$$
		select * from view_game
		where black = $1 or white = $1
	$$
;


-- moves(game_id)
-- returns all moves of game given a game_id
create or replace function moves(game_id integer) returns setof view_gamemove language sql as
	$$
		select * from view_gamemove where game_id = $1
		order by movenum, iswhite desc
	$$
;

-- openingmoves(board)
-- returns all possible opening branches given a position
-- XXX  It is not enforeced that this will return san moves that are all unique 
-- 		but it *should* if the eco file is setup correctly.
create or replace function openingmoves(board) returns setof view_openingmove language sql as
	$$
		-- recreate view_openingmove so we can use indexes
		select 
			openingmove.id
			,opening.eco
			,opening.nick as opening
			,opening.variation 
			,opening.subvar
			,opening.c_move_count
			,movenum
			,iswhite
			,move
			,position_move_san(tofen(position_id), move) as san
			,position_id as board_before
			,toboard(position_make_move(tofen(position_id), move)) as board_after
			--,fiftymove
		from
		-- We want to find openings with the fewest moves as eco codes are setup like
		-- a tree where the opening start from the most general at the trunk to the most
		-- specialized at the leaves.
		(
			select min(c_move_count)
			from
			(
				select c_move_count, move, opening.id
				from openingmove 
					join opening on opening.id = opening_id
				where position_id = $1
			) t
		) tt
		-- join back on minimum move
		join opening
			on c_move_count = min
		join openingmove
			on opening.id = opening_id
		where position_id = $1
	$$
;

-- we need this function so we can put the move array in the expression list
-- and not have it complain about returning more than one row.
create or replace function opening_moves(opening_id bigint) returns text[] language sql as

	$$
			select 
				array_agg(position_move_san(tofen(position_id), move)) as moves
			from 
			(
				select *
			 	from openingmove 
				where opening_id = $1
				order by movenum, iswhite desc
			) t
	$$
;

-- classify_opening(board, move)
-- returns the opening given a starting position and the move made
create or replace function classify_opening(board, move) returns setof view_opening language sql as
	$$
		-- recreate view_opening so we can use indexes
		select 
			opening.id
			,eco
			,opening.nick as opening
			,opening.variation 
			,opening.subvar
			,opening_moves(opening.id)

		from
		-- We want to find openings with the fewest moves as eco codes are setup like
		-- a tree where the opening start from the most general at the trunk to the most
		-- specialized at the leaves.
		(
			select min(c_move_count)
			from
			(
				select c_move_count, move, opening.id
				from openingmove 
					join opening on opening.id = opening_id
				where 
					position_id = $1
					and move = $2
			) t
		) tt
		-- join back on minimum move
			join opening
				on c_move_count = min
			join openingmove
				on opening.id = opening_id


		where position_id = $1 and move = $2
		group by opening.id ,eco, opening ,variation, subvar


	$$
;

-- classify_opening(game_id)
-- returns the last known opening given a game_id
create or replace function classify_opening(game_id bigint) returns view_opening language sql as
	$$
		select
			classify_opening(position_id, move)
		from
		(
			select
				 position_id
				,movenum
				,iswhite
				,move
			from gamemove
			where game_id = $1
			-- reverse moves so the most specific is at the top
			order by movenum desc, iswhite
		) as t
		-- just take the first one
		limit 1
	$$
;

create or replace function variations(position_id board) returns setof move language sql as
	$$
		select
		move
		-- group the last position so we have move transpositions
		from 
		(
			select 
				position_id
				,move
			from gamemove 
			where 
				position_id = $1
			group by move, position_id
		)  as t 
	$$
;

create or replace function variationstats(position_id board, cutoff integer default 5) 
	returns setof view_positionstat language sql as
	$$
		select 
			view_positionstat.* 
		from 
			view_positionstat 
		where view_positionstat.position_id  = $1
		and total >= $2
		order by white_winr desc
	$$
;




--validmoves(fen)
--attacked(fen)
--protected(fen)

--attack_sum(fen)


-- NEED: makemove(from, to)

