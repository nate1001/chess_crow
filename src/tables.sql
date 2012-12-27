/* Copyright Nate Carson 2012 */

/*
A FEN "record" defines a particular game position, all in one text line and using only the ASCII character set. A text file with only FEN data records should have the file extension ".fen".
A FEN record contains six fields. The separator between fields is a space. The fields are:

- Piece placement (from white's perspective). Each rank is described, starting with rank 8 and ending with rank 1; within each rank, the contents of each square are described from file "a" through file "h". Following the Standard Algebraic Notation (SAN), each piece is identified by a single letter taken from the standard English names (pawn = "P", knight = "N", bishop = "B", rook = "R", queen = "Q" and king = "K").[1] White pieces are designated using upper-case letters ("PNBRQK") while black pieces use lowercase ("pnbrqk"). Blank squares are noted using digits 1 through 8 (the number of blank squares), and "/" separates ranks.

- Active color. "w" means white moves next, "b" means black.

- Castling availability. If neither side can castle, this is "-". Otherwise, this has one or more letters: "K" (White can castle kingside), "Q" (White can castle queenside), "k" (Black can castle kingside), and/or "q" (Black can castle queenside).

- En passant target square in algebraic notation. If there's no en passant target square, this is "-". If a pawn has just made a two-square move, this is the position "behind" the pawn. This is recorded regardless of whether there is a pawn in position to make an en passant capture.[2]

- Halfmove clock: This is the number of halfmoves since the last pawn advance or capture. This is used to determine if a draw can be claimed under the fifty-move rule.

- Fullmove number: The number of the full move. It starts at 1, and is incremented after Black's move.

http://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation
*/

\set ON_ERROR_STOP
set client_min_messages=WARNING;

--------------------------------------
--	tables  --------------------------
--------------------------------------

drop table if exists position cascade;
create table position(
	id				board		primary key
);


drop table if exists player cascade;
create table player(
	id				serial			primary key
	,nick			text			not null

	,unique (nick)
);


drop table if exists game cascade;
create table game(
	id				serial			primary key
	,event			text			not null
	,site			text			not null
	,date_			date			not null
	,round			text			not null
	,wplayer_id		integer			not null	references player(id)
	,bplayer_id		integer			not null	references player(id)
	,result			gameresult 		not null

	,unique (event, site, date_, round, wplayer_id, bplayer_id, result)
);


drop table if exists opening cascade;
create table opening(
	id				serial			primary key
	,nick			text			not null
	,variation		text			not null
	,subvar			integer			not null
	,eco			varchar(4) 		not null
	,c_move_count integer

	,unique (nick, variation, subvar)
);


drop table if exists gamemove cascade;
create table gamemove(
	id				serial			primary key
	,game_id		integer			not null	references game(id)
	,position_id 	board			not null	references position(id)
	,movenum		integer 		not null	
	,iswhite		boolean 		not null
	,move			move			not null

	-- TODO
	-- ,checkstatus	checkstatus
	,fiftymove		integer

	,unique (game_id, movenum, iswhite)
);
create index on gamemove(game_id);
create index on gamemove(position_id);

drop table if exists openingmove cascade;
create table openingmove( like gamemove including all);
alter table openingmove drop column game_id;
alter table openingmove add column opening_id integer not null references opening(id);
create index on openingmove(position_id);



