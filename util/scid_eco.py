

'''
The database needs to have unique opening names to be able to find transpositions. 
The scid eco file has duplicate openings names that break uniquness in the database.
We fix this with script wich adds a opening sub variation number to our dump file 
that guarentees uniqueness for each opening.

'''


class ScidEco(object):

	eco, variation, result, _a, pgn, _b = range(6)
	
	def __init__(self, idx, eco, opening, variation):
		
		# fix variations stuck to opening
		if variation == '\\N' and opening.find(',') > -1:
			variation = ','.join(opening.split(',')[1:]).strip()
			opening = opening.split(',')[0].strip()

		# dont allow null variations
		if variation == '\\N':
			variation = ''

		self.idx = idx
		self.eco = eco
		self.opening = opening
		self.variation = variation
		self.subvar = 1
	
	def __str__(self):
		return "%s\t%s\t%s\t%s\t%s\n" %(self.idx, self.eco, self.opening, self.variation, self.subvar)
	
	# eco is not unique for every opening / variation ! why?
	def __eq__(self, other):
		return self.opening == other.opening \
			and self.variation == other.variation


old = open("../data/eco.tags.dump")
new = open("../data/eco_fixed.tags.dump", 'w')

scids = []
dups = 0
total = 0

for line in old:
	
	idx, eco, opening, variation = line.rstrip().split("\t")

	scideco = ScidEco(idx, eco, opening, variation)
	for other in scids:
		# eco can change while the opening is called the same thing
		# so we cant cut off early 
		#if other.eco[:1] != scideco.eco[:1]:
		#	break

		#found the dup, make it unique
		if scideco == other:
			dups += 1
			scideco.subvar = other.subvar + 1
			break
	# inert at 0 so we do not have search through haystack of non matches
	new.write(str(scideco))
	scids.insert(0, scideco)
	total += 1
	print total




