addprocs(3-length(procs())) 

@everywhere using Distributions

@everywhere type Player
  belief
  result
  friends
  goodfriends
  #n
end

@everywhere type Game
  binom_n
  epsilon
  players
  observers
#  converged
#  round_converged
end

@everywhere Game() = Game(0,0,[],[])

@everywhere function Update(game,player)
  for i in player.goodfriends
    top = (1-player.belief)*((.5-game.epsilon)/(.5+game.epsilon))^(2*game.players[i].result-game.binom_n)
    player.belief = 1/(1+top/player.belief)
  end
end

@everywhere function Round(game,propagandist)
  for x in game.players
    y = []
    for z in x.friends
      if game.players[z].belief > .5
        y = vcat(y,z)
      end
    end
    x.goodfriends = y
    if x.belief > .5
      x.result = rand(Binomial(game.binom_n,.5+game.epsilon))
    end
  end
  for x in game.observers
    y = []
    for z in x.friends
      if game.players[z].belief > .5
        y = vcat(y,z)
      end
    end
    if propagandist
      for z = 1:length(game.players)
        if game.players[z].result < game.binom_n/2
          y = vcat(y,z)
        end
      end
    end
    x.goodfriends = y
  end
  for x in game.players
    Update(game,x)
  end
  for x in game.observers
    Update(game,x)
  end
end

@everywhere function InitializeGame(game,network,popSize,binom_n,epsilon)
  game.binom_n = binom_n
  game.epsilon = epsilon
  game.players = Array{Player}(popSize)
  game.observers = Array{Player}(popSize)
#  game.converged = 0
#  game.round_converged = 0

  if network == "cycle"
    game.players[1] = Player(rand(),0,[1,2,popSize],[])
    game.players[popSize] = Player(rand(),0,[popSize-1,popSize, 1],[])

    for i = 2:(popSize-1)
      game.players[i] = Player(rand(),0,[i-1,i, i+1],[])
    end
    y = Array(Int64,0)
    for i = 1:popSize
      y = vcat(y,i)
      game.observers[i] = Player(rand()/2,0,y,[])
    end
  elseif network == "complete"
    x = []
    for j = 1:popSize
      x = vcat(x,j)
    end
    for i = 1:popSize
      game.players[i] = Player(rand(),0,x,[])
    end
    y = Array(Int64,0)
    for i = 1:popSize
      y = vcat(y,i)
      game.observers[i] = Player(rand()/2,0,y,[])
    end
  else
    error("no such network type")
  end
end

@everywhere function reInitializeGame(game)
#  game.converged = 0
#  game.round_converged = 0

  for x in game.players
    x.belief = rand()
  end
  for x in game.observers
    x.belief = rand()/2
  end
end

@everywhere function DoIt(popSize, networkType, epsilon, binom_n, runs,propagandist)
  #numberConverged = 0
  #sumRoundConverged = 0

  Zollman = Game()

  InitializeGame(Zollman,networkType,popSize,binom_n,epsilon)
  results=Array(Int64,(0,popSize+1))

  for x = 1:runs
    roundCounter = 0
    convergenceCheck = 0

    while convergenceCheck == 0
      y=[]
      for x in Zollman.players
        y=vcat(y, x.belief)
      end
      if minimum(y) >= .99
        convergenceCheck = 1
        #sumRoundConverged = sumRoundConverged + roundCounter
        summary = Array(Float64,(1,0))
        summary = hcat(summary,roundCounter)
        for x in Zollman.observers
          summary = hcat(summary,x.belief)
        end
        results = vcat(results,summary)

        #numberConverged = numberConverged + 1
      elseif maximum(y) <= .5
        convergenceCheck = 1
      end

      Round(Zollman,propagandist)
      roundCounter += 1
    end

    reInitializeGame(Zollman)
  end

  mean(results,1)
  #println("Portion Converged: ", numberConverged/runs)
  #println("Average Round Converged: ", sumRoundConverged/numberConverged)
end


for popSize in [30]
  #results = Array(Any,(0,popSize+6))
  for binom_n in [10]
    for epsilon in [.05]
      for prop in [false]
        proc2 = @spawn DoIt(popSize,"complete",epsilon,binom_n,500,prop)
        proc1 = @spawn DoIt(popSize,"complete",epsilon,binom_n,500,prop)
        #println(hcat([popSize "complete" epsilon binom_n prop], mean([fetch(proc1),fetch(proc2)])))
        results = vcat(results,DoIt(popSize,"cycle",epsilon,binom_n,1000,prop))
      end
    end
  end
  writecsv("Cailin extra data no prop popSize$popSize.csv", results)
end

#writecsv("Results NoProp Size$popSize Binom$binom_n Eps$epsilon Complete.txt", DoIt(6,"complete",epsilon,binom_n,10,false))
#writecsv("Results NoProp Size$popSize Binom$binom_n Eps$epsilon Cycle.txt", DoIt(6,"cycle",epsilon,binom_n,10,false))
#writecsv("Results Prop Size$popSize Binom$binom_n Eps$epsilon Complete.txt", DoIt(6,"complete",epsilon,binom_n,10,true))
#writecsv("Results Prop Size$popSize Binom$binom_n Eps$epsilon Cycle.txt", DoIt(6,"cycle",epsilon,binom_n,10,true))

#writecsv("results.csv",DoIt)