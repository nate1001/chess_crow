/* Copyright Nate Carson 2012 */

\set ON_ERROR_STOP

set DYNAMIC_LIBRARY_PATH to
    '$libdir'
	    ':/home/muskrat/src/chess/trunk/src/build/lib'
		; load 'libpgchess';

--------------------------------------

--	functions  -----------------------

--------------------------------------


--------------------------------------
--	board and fen  -------------------
--------------------------------------




-- reversecolor(fen)
-- returns the fen with the color reversed
create or replace function reversecolor(fen) returns fen language sql immutable as
	$$
		select 
		(
			split_part($1, ' ', 1) || ' '
			|| case when split_part($1, ' ', 2) = 'b' then 'w' else 'b' end || ' '
			|| split_part($1, ' ', 3) || ' '
			|| split_part($1, ' ', 4)
		)::fen
	$$
;


-- tofen(boardstring, color, castleclass, algsquare)
-- returns fen from boardstring
create or replace function tofen(boardstring, color, castleclassgroup, algsquare) returns fen language sql immutable as
	$$
			select
			(
				board || ' ' ||
				case
					when $2='white' then 'w' else 'b'
				end ||
				' ' || coalesce($3, '-') || 
				' ' || coalesce($4::text, '-')
			)::fen
			from
			(
				-- replace groups of '.' with numbers
				select replace( replace( replace( replace( replace( replace( replace( replace( 
					string_agg, '........', '8'),
					'.......', '7'),
					'......', '6'),
					'.....', '5'),
					'....', '4'),
					...', '3'),
					'..', '2'),
					'.','1') as board
				from
				(
					select
						-- add a slash for every 8 characters
						string_agg(substring($1 from n*8-7 for 8), '/') 
					from 
						generate_series(1,8) as n
				) as tt
			) as t



	$$
;


-- toboardindex(algsquare)
-- returns string position of boardstring given an algsquare
create or replace function toboardindex(algsquare) returns boardindex language sql immutable as
	$$
		select 
		(
			( (ascii(substring($1::text from 1 for 1)) -104) * -8  ) 
			+ ( substring($1::text from 2 for 1)::int)
		)::boardindex
	$$
;


-- toalgsquare(boardindex)
-- returns algsquare given an boardindex
create or replace function toalgsquare(boardindex) returns algsquare language sql immutable as
	$$
		select 
		(
			chr( ((64 - $1) / 8) + 97)
			|| 7 - (64 - $1) % 8 + 1
		)::algsquare
	$$
;



-- toiswhite(fen)
-- returns whether is true that white has the move
create or replace function toiswhite(fen) returns boolean language sql immutable as
	$$
			select 
			case 
				when m = 'w' then true
				when m = 'b' then false
				else null::boolean
			end
			from split_part($1, ' ', 2) as m
	$$
;

-- tocolor(fen)
-- returns color of piece given the fen
create or replace function tocolor(fen) returns color language sql immutable as
	$$
		select case
			when toiswhite($1) = true then 'white'::color
			else 'black'::color
		end
	$$
;

-- tocastleclass(fen)
-- returns what types of castling are still available
create or replace function tocastleclass(fen) returns setof castleclass language sql immutable as
	$$
			select p
			from
			(
					select 
						case when p = '-' then null::castleclass
						else p::castleclass
					end as p
					from regexp_split_to_table(split_part($1, ' ', 3), '') as p
			) as t
			group by p -- remove duplicates
			order by p
	$$
;

-- toenpassant(fen)
-- returns the enpassant square if available
create or replace function toenpassant(fen) returns algsquare language sql immutable as
	$$
			select 
			case 
				when p = '-' then null::algsquare
				else p::algsquare
			end
			from split_part($1, ' ', 4) as p
	$$
;

/*
-- print(boardstring)
-- prints and unicode string representing the board
create or replace function print(boardstring) returns text language sql immutable as
$$
	select
	string_agg
	(
		case 
			when substring($1 from idx for 1) = '.'
				then '.'
			else 
				tosymbol((substring($1 from idx for 1)::piececlass))
		end
		|| 
		case when idx % 8 = 0 then e'\n' else '' end

	, '')
	from
	generate_series(1, 64) as idx
$$;

create or replace function print(fen) returns text language sql immutable as
$$
	select print(toboardstring($1))	
$$;
*/



--------------------------------------
--	pieces ---------------------------
--------------------------------------


/*
-- tocolor(piececlass)
-- returns color of piece given a piece
create or replace function tocolor(piececlass) returns color language sql immutable as
	$$
		select case
			when ($1::text) ~ '[a-z]' then 'black'::color
			else 'white'::color
		end
	$$
;
drop cast if exists (piececlass as color);
create cast(piececlass as color) with function tocolor(piececlass);


-- topiecetype(piececlass)
-- returns generic type of piece from piececlass
create or replace function topiecetype(piececlass) returns piecetype language sql immutable as
	$$
		select lower($1::text)::piecetype
	$$
;
drop cast if exists(piececlass as piecetype);
create cast(piececlass as piecetype) with function topiecetype(piececlass);


-- tovalue(piececlass)
-- returns nominal value of piece given a piece
create or replace function tovalue(piececlass) returns integer language sql immutable as
	$$
		select 
			case
				when piece = 'p' then 1
				when piece = 'b' then 3
				when piece = 'n' then 3
				when piece = 'r' then 5
				when piece = 'q' then 9
				when piece = 'k' then 200
			end
		from
			lower($1::text) as piece
	$$
;

-- tosymbol(piececlass)
-- returns unicode symbol of piececlass
create or replace function tosymbol(piececlass) returns text language sql immutable as
	$$
		select 
			case
				when $1 = 'p' then '♙'
				when $1 = 'b' then '♗'
				when $1 = 'n' then '♘'
				when $1 = 'r' then '♖'
				when $1 = 'q' then '♕'
				when $1 = 'k' then '♔'
				when $1 = 'P' then '♟'
				when $1 = 'B' then '♝'
				when $1 = 'N' then '♞'
				when $1 = 'R' then '♜'
				when $1 = 'Q' then '♛'
				when $1 = 'K' then '♚'
			end
	$$
;
*/


-- tocolor(iswhite boolean)
-- returns color of piece given true or false
create or replace function tocolor(iswhite boolean) returns color language sql immutable as
	$$
		select (case when $1 = true then 'white' else 'black' end)::color
	$$
;


-- inverse(color)
-- returns the other color
create or replace function inverse(color) returns color language sql immutable as
	$$
		select case
			when $1 = 'white' then 'black'::color
			else 'white'::color
	end
	$$
;



