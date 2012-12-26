
from subprocess import PIPE, Popen


class PV(object):
	def __init__(self, line):
		pieces = line.split()
		self._getToken(pieces, 'info')
		self._getToken(pieces, 'depth')
		self.depth = int(self._getToken(pieces))
		self._getToken(pieces, 'seldepth')
		self.seldepth = int(self._getToken(pieces))
		self._getToken(pieces, 'score')
		self._getToken(pieces, 'cp')
		self.score = int(self._getToken(pieces))

		if pieces[0] == 'lowerbound':
			pieces.pop(0)
		if pieces[0] == 'upperbound':
			pieces.pop(0)

		self._getToken(pieces, 'nodes')
		self.nodes = int(self._getToken(pieces))
		self._getToken(pieces, 'nps')
		self.nps = int(self._getToken(pieces))
		self._getToken(pieces, 'time')
		self.time = int(self._getToken(pieces))
		self._getToken(pieces, 'multipv')
		self.multipv = int(self._getToken(pieces))
		self._getToken(pieces, 'pv')
		self.pv = []
		while pieces:
			self.pv.append(self._getToken(pieces))

	def __str__(self):
		return "<PV d=%s cp=%s t=%s m=%s>" %(
			self.depth, self.score, self.time, self.pv)
	
	def _getToken(self, pieces, check=None):
		token = pieces.pop(0)
		if check and token != check:
			raise ValueError(token)
		return token



class PVList(list): 
	def __init__(self):
		list.__init__(self)
		self.bestmove = None
		self.ponder = None
	
	def bestLine(self):
		return self[-1]
	
		

class Engine(object):
	
	def __init__(self, path):

		self.path = path
		self.stdin, self.stdout = None, None

	def connect(self):
		p = Popen(self.path, stdin=PIPE, stdout=PIPE, close_fds=True, bufsize=1)
		self.stdin, self.stdout = (p.stdin, p.stdout)
		self.wait_for_output()
	
	def wait_for_output(self):

		buf = []
		while True:
			c = self.stdout.read(1)
			if c == '\n':
				break
			buf.append(c)
		return ''.join(buf)
	
	def send_command(self, command):
		self.stdin.write(command + '\n')


class UCIEngine(Engine):
	
	def __init__(self, path):
		Engine.__init__(self, path)
	
	def isready(self):
		self.send_command("isready")
		if self.wait_for_output() == 'readyok':
			return True
		return False
	
	def position(self, fen=''):
		if not fen:
			self.send_command("position startpos")
		else:
			self.send_command("position fen %s" % fen)
		self.isready()
	
	def go(self, depth):
		lines = PVList()
		self.send_command("go depth %s" % depth)
		while True:
			line = self.wait_for_output()
			if line.split()[0] == 'bestmove':
				break
			if line.split()[3] == 'currmove':
				continue	
			lines.append(PV(line))
		return lines
	


if __name__ == '__main__':
	engine = UCIEngine('src/stockfish')
	engine.connect()
	engine.position('6k1/2p1R3/3p4/b4KP1/4P3/3P4/8/8 w - -')
	print engine.go(5).bestLine()

