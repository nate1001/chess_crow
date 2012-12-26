
'''
Takes Pgn files and creates files that are appropiate for Postgresql copy command.
'''

from commands import getstatusoutput as gso


def boardIndex(square):
	file, rank = square
	rank = int(rank)
	if rank < 1 or rank > 8:
		raise ValueError(square)
	file = {'a':0, 'b':1, 'c':2, 'd':3, 'e':4, 'f':5, 'g':6, 'h':7}[file]
	return (8 - rank) * 8 + file


#FIXME import this
def boardstring(fen):
	return (fen.split()[0].replace('/','').
		replace('8', '........').
		replace('7', '.......').
		replace('6', '......').
		replace('5', '.....').
		replace('4', '....').
		replace('3', '...').
		replace('2', '..').
		replace('1', '.')
	)

class Parser(object):

	result = ['1-0', '0-1', '1/2-1/2', '*']

	def __init__(self):
		self._tags = {}
		self._pgn = []
		self._moves = []
		self.games = {'tags': [], 'moves': []}

	
	def handleEnd(self):
		self.games['moves'].append(self._moves)
		self.games['tags'].append(self._tags)
		self._moves = []
		self._tags = {}

	def handleMovenum(self, item):
		if item in Parser.result:
			self.handleResult(item)
		else:
			movenum = int(item.strip()[:-1])
			movelen = len(self._moves) / 2 + 1
			if  movenum != movelen:
				raise ValueError('movenum %s inconsistant with move length %s' % (movenum, movelen))

	def handleMove(self, item, iswhite):
		if item in Parser.result:
			self.handleResult(item)
		else:
			self._moves.append(item)
	
	def handleResult(self, item):
		pass

	def parse(self, name):
		s, o = gso(self.command %(name))
		if s:
			raise OSError(o)
		return o

	def _handle_tag(self, line):
		key, value = line[1:-3].split(' "')
		self._tags[key.lower()] = value

	def _handle_pgn(self, line):
		self._pgn.append(line)

	def _end_pgn(self):
		if not self._pgn:
			return
		for idx, item in enumerate(' '.join(self._pgn).split()):
			if idx % 3 == 0:
				self.handleMovenum(item)
			elif idx % 3 == 1:
				self.handleMove(item, True)
			elif idx % 3 == 2:
				self.handleMove(item, False)
			else:
				raise ValueError(item)
		self.handleEnd()
		self._pgn = []

		

class ElalgParser(Parser):
	name = 'tmp1.elalg'
	command = './pgn-extract %s -Welalg > ' + name

	def parse(self, name):
		super(ElalgParser, self).parse(name)

		for line in open(self.name):
			if line.startswith('['):
				self._handle_tag(line)
			elif line.strip():
				self._handle_pgn(line)
			else:
				self._end_pgn()

		return self.games


class SanParser(ElalgParser):
	name = 'tmp1.san'
	command = './pgn-extract %s -Wsan> ' + name



class EpdParser(Parser):
	name = 'tmp1.epd'
	command = './pgn-extract %s -Wepd > ' + name

	def __init__(self):
		self.games = {'fen': []}
		self._fen = []

	def parse(self, name):
		super(EpdParser, self).parse(name)

		self.games = {'fen': []}
		for line in open(self.name):
			if not line.strip():
				self.handleEnd()
			else:
				self._fen.append(' '.join(line.split()[:5]))

		return self.games

	
	def handleEnd(self):
		self.games['fen'].append(self._fen)
		self._fen = []

class PgnGames(object):

	@staticmethod
	def iterGame(game):
		for idx in range(len(game['san'])):
			san = game['san'][idx]
			elalg = game['elalg'][idx]
			epd = game['epd'][idx]
			# Remove draw count from fen as pgn-parser does not calculate it.
			epd = ' '.join(epd.split()[:4])
			iswhite = idx % 2 == 0

			last_epd = game['epd'][idx]
			tags = game['tags']


			# if its a castle

			# could be check or mate also so take a slice
			# check queenside first since the queenside slice will match the kingside slice
			if san[:5] == 'O-O-O' and iswhite:
				subject = 'K'
				start = 'e1'
				end = 'c1'
			elif san[:5] == 'O-O-O' and not iswhite:
				subject = 'k'
				start = 'e8'
				end = 'c8'
			elif san[:3] == 'O-O' and iswhite:
				subject = 'K'
				start = 'e1'
				end = 'g1'
			elif san[:3] == 'O-O' and not iswhite:
				subject = 'k'
				start = 'e8'
				end = 'g8'
				
			# if its a piece move
			elif elalg[0].isupper():
				subject = elalg[0]
				# if the move is black then change the piece to lowercase
				if not iswhite:
					subject = subject.lower()
				start = elalg[1:3]
				end = elalg[3:5]

			#else if its a white pawn move
			elif iswhite:
				subject = 'P'
				start = elalg[0:2]
				end = elalg[2:4]

			#else if its a black pawn move
			elif not iswhite:
				subject = 'p'
				start = elalg[0:2]
				end = elalg[2:4]

			target = boardstring(last_epd)[boardIndex(end)]
			movenum = idx / 2 + 1
			
			yield [str(movenum), str(iswhite), start, end, subject, target, epd, san]

	@staticmethod
	def fromFile(name):
		
		games = {}
		san = SanParser()
		elalg = ElalgParser()
		epd = EpdParser()

		d = san.parse(name)
		games['san'] = d['moves']
		games['tags'] = d['tags']
		games['elalg'] = elalg.parse(name)['moves']
		games['epd'] = epd.parse(name)['fen']

		return PgnGames(games)
	
	def __init__(self, games):
		
		self.san = games['san']
		self.tags = games['tags']
		self.epd = games['epd']
		self.elalg = games['elalg']
	
	def __iter__(self):
		
		if len(self.san) != len(self.epd) != len(self.tags) != len(self.elalg):
			raise ValueError('attributes do not have the same length')

		for idx in range(len(self.san)):
			yield {
				'san': self.san[idx],
				'tags': self.tags[idx],
				'epd': self.epd[idx],
				'elalg': self.elalg[idx],
			}
		

SEVEN = ['event', 'site', 'date', 'round', 'white', 'black', 'result']
ECO = ['eco', 'opening', 'variation']
def get_tags(rounds, tags, taglist):
	newtags = []
	null = '\\N'
	for tag in taglist:
		if tags.has_key(tag):
			#XXX scid eco KluDge
			if tag == 'variation':
				if tags['variation'].find(':') > -1:
					opening = tags['variation'].split(':')[0]
					variation = ':'.join(tags['variation'].split(':')[1:])
				else:
					opening, variation = tags['variation'], null
				newtags.extend([opening, variation])

			elif tag == 'round' and tags['round'] == '?':
				newtags.append(str(rounds))
			elif tags[tag] == '?':
					#newtags[tag] = null -- XXX if we have an unknown field db will never find dups
					newtags.append(tags[tag])
			else:
					newtags.append(tags[tag])
	return newtags


def outputDumpFile(pgnname, dumpname, taglist=SEVEN):

	games = PgnGames.fromFile(pgnname)
	print 'pgn parsed.'

	moves = open(dumpname + '.moves.dump', 'w')
	tags = open(dumpname + '.tags.dump', 'w')
	for idx, game in enumerate(games):
		tags.write(str(idx) + '\t' + '\t'.join(get_tags(idx, game['tags'], taglist)) + '\n')
		for move in PgnGames.iterGame(game):
			moves.write(str(idx) + '\t' + '\t'.join(move) + '\n')


if __name__ == '__main__':
	#outputDumpFile('../data/games.pgn', '../data/games')
	outputDumpFile('../data/scid_eco.pgn', '../data/eco', taglist=ECO)
	
	


