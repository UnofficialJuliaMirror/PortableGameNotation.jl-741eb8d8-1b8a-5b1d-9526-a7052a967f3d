
module PortableGameNotation

import Base.repr, Base.length

export readpgn, writepgn, Game, event, site, date, round, white, black, result,
  whiteelo, blackelo, eventdate, eco, movetext, plycount, length, movestring,
  headerstring, repr, intresult, whiteev, blackev, whitescore, blackscore

type Game
  header::Dict{String, String}
  movetext::String
end

RESULT_HASH = Dict{AbstractString,Int}("1-0" => 1, "1/2-1/2" => 0, "0-1" => -1, "*" => 0)
REQUIRED_TAGS = ["Event", "Site", "Date", "Round", "White", "Black", "Result"]
DEFAULT_HASH = Dict("Event"=>"","Site"=>"","Date"=>"","Round"=>"","White"=>"",
  "Black"=>"","Result"=>"")

function headerstring(g::Game)
  s = String[]
  # tags required by standard must be printed first and in order
  for t in REQUIRED_TAGS
    push!(s, "[$t \"$(g.header[t])\"]\n")
  end
  for k in keys(g.header)
    if !(k in REQUIRED_TAGS)
      push!(s, "[$k \"$(g.header[k])\"]\n")
    end
  end
  join(s, "")
end

function movestring(g::Game; line=80)
  moves = split(g.movetext)
  s = String[]
  n = 0
  for m in moves
    push!(s, m)
    push!(s, " ")
    n += length(m) + 1
    if n >= line
      push!(s, "\n")
      n = 0
    end
  end
  join(s, "")
end

Base.repr(g::Game) = headerstring(g) * "\n" * movestring(g)

println(g::Game) = println(repr(g))


function length(g::Game)
  # length is defined as number of moves
  moves = split(g.movetext,".")
  n = length(moves) - 1
  return n
end

function validate(g::Game)
  for t in REQUIRED_TAGS
    if !(t in keys(g.header))
      return false
    end
  end
  return true
end

function query(g::Game, key::String, default="?")
  try
    return g.header[key]
  catch KeyError
    return default
  end
end
function intquery(g::Game, key::String, default=0)
  s = query(g, key)
  try
    t = parse(Int, s)
  catch ArgumentError
    return default
  end
end

white(g::Game) = query(g, "White")
black(g::Game) = query(g, "Black")
date(g::Game) = query(g, "Date")
site(g::Game) = query(g, "Site")
event(g::Game) = query(g, "Event")
result(g::Game) = query(g, "Result", "*")
whiteelo(g::Game) = intquery(g, "WhiteElo")
blackelo(g::Game) = intquery(g, "BlackElo")
eco(g::Game) = query(g, "ECO")
eventdate(g::Game) = query(g, "EventDate")
plycount(g::Game) = intquery(g, "PlyCount")
movetext(g::Game) = g.movetext

intresult(g::Game) = RESULT_HASH[query(g, "Result", "1/2-1/2")]

whiteev(g::Game) = 1. / (1. + 10^((blackelo(g)-whiteelo(g)) / 400.0))
blackev(g::Game) = 1. / (1. + 10^((whiteelo(g)-blackelo(g)) / 400.0))
whitescore(g::Game) = 0.5*(intresult(g) + 1)
blackscore(g::Game) = 0.5*(1 - intresult(g))

isdecisive(g::Game) = g.header["Result"] != "1/2-1/2"

const STATE_HEADER = 0
const STATE_MOVES = 1
const STATE_NEWGAME = 2

isblank(line) = all(isspace, line)

function readpgn(pgnfilename; header=true, moves=true)
  f = open(pgnfilename,"r")
  pgn = readlines(f)
  close(f)
  games = Vector{Game}()
  #g = Game()
  m = String[]
  h = Dict{String,String}()
  state = STATE_NEWGAME
  for l in pgn
    #println("LINE> $l")
    if ismatch(r"^\[", l)   # header line
      state = STATE_HEADER
      fields = split(l,'\"')
      key = fields[1][2:end-1]
      val = fields[2]
      if header
        h[key] = val
      end
    elseif isblank(l) && state == STATE_HEADER
      state = STATE_MOVES  # TODO: allow for multiple blank lines after header?
    elseif !isblank(l) && state == STATE_MOVES && moves
      push!(m, chomp(l))
    elseif isblank(l) && state == STATE_MOVES
      push!(games, Game(h, join(m, " ")))
      state = STATE_NEWGAME
    end
    if state == STATE_NEWGAME
      m = String[]
      h = Dict{String,String}()
    end
  end
  if state == STATE_MOVES
    push!(games, Game(h, join(m, " ")))
  end
  return games
end

function sortpgnfile(pgnfilename, outfile)
  data = readpgn(pgnfilename)
  datasorted=sort(data, by=cpsort)
  f = open(outfile, "w")
  for d in datasorted
    write(f, repr(d))
  end
  close(f)
end


function browsepgn(pgnfilename)
  data = readpgn(pgnfilename)
  datasorted = sort(data, by=cpsort)
  n = 1
  while true
    println("=========================== GAME $n ===========================")
    gamestats(datasorted[n])
    key = read(STDIN,Char)
    if key == 'q'
      break
    elseif key == 'j'
      n += 1
    elseif key == 'k'
      n -= 1
    elseif key == 'J'
      n += 10
    elseif key == 'K'
      n -= 10
    end
    n = n % length(datasorted)  # wrap around
  end
end


end
