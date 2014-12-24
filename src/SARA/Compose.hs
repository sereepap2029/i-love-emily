{-----------------------------------------------------------------------------
    SARA
------------------------------------------------------------------------------}
module SARA.Compose where

import           Data.List         ((\\))
import qualified Data.Map   as Map
import           Data.Maybe

import SARA.Database
import SARA.Types
import Types

-- | Global setting that indicates how much the composition
-- algorithm should recombine existing material.
recombinance = 80


-- | This is the workhorse compose function.
simpleCompose :: Database -> Name -> Name -> Int -> Meter -> Prob [([AnalysisLabel], Notes)]
simpleCompose db name measureName number meter
    | number == 0 = return []
    | otherwise   = do
        x   <- interchangeChannels db measureName meter
        new <- newMeasure
        xs  <- simpleCompose db name new (next number) meter
        return (x:xs)

    where
    -- *cadence-match*
    cadenceMatch =
        if  isMatch (evalMeasure db measureName)
            && number == 1
            && isNothing (nextMeasure db measureName)
            && isMatch (evalCadence db (getPhrase measureName))
        then Just $ getPhrase measureName
        else Nothing

    next n = n - 1  -- simpleCompose counts down until it reaches 0.

    -- Choose the next measure.
    newMeasure
        -- return the original next measure if we want to match closely
        | isMatch (evalMeasure db measureName),
          Just next <- nextMeasure db measureName,
          isMatch (evalMeasure db next) =
            return next

        -- make a new choice
        | otherwise = makeBestChoice (getDestinationNote measureName)
                        list (getNewFirstNotesList list)
        where
        list
            | number == 2 = getPredominant destinations -- choose predominant
            | otherwise   = removeMatchedObjects (removeLastChord lastChord destinations)
            -- warning: removeLastChord has side effects

    getDestinationNote = head . fst . destination . evalMeasure db

    destinations = getDestinations db name measureName meter
    lastChord    = getLastChord db name measureName


-- | Get measures name that have the same analysis label as the destination.
getDestinations :: Database -> Name -> Name -> Meter -> [Name]
getDestinations db name measureName meter =
    fromJust $ Map.lookup meter (functionList lexicon)
    where
    analysis = snd $ destination $ evalMeasure db measureName
    lexicon  = evalLexicon db name analysis
    -- If this lexicon doesn't exist, then pick from the network
    {-
      (let ((new-test (concat name '- (first *network*) '-lexicon)))
            (setq *network* (nthcdr *meter* *network*))
                       new-test))))))
    -}


-- | Return a measure name that has the closes starting pitch.
makeBestChoice :: Pitch -> [Name] -> [Pitch] -> Prob Name
makeBestChoice pitch xs ys = findClosest pitch $ zip xs ys

findClosest :: Pitch -> [(a,Pitch)] -> Prob a
findClosest x ys = choose $ map fst $ filter ((dist ==) . distance) ys
    where
    distance (_,y) = abs $ x - y
    dist           = minimum $ map distance ys



getNewFirstNotesList = undefined
getPredominant       = undefined
removeMatchedObjects = undefined

-- | Remove an element from the list, but only if it is not the only element.
removeLastChord :: Eq a => a -> [a] -> [a]
removeLastChord _ [x] = [x]
removeLastChord x xs  = xs \\ [x]

getLastChord         = undefined
spliceChannels       = undefined

-- | Return analysis and music, but with music from other
-- appropriate measures interleaved.
interchangeChannels :: Database -> Name -> Meter -> Prob ([AnalysisLabel],Notes)
interchangeChannels db measureName meter = do
    k <- makeRandom 100
    return (analysis measure,
        if recombinance > 60 && k < recombinance
        then spliceChannels db measureName meter
        else music measure)
    where
    measure = evalMeasure db measureName


-- | Randomly choose a pickup.
--
-- This function seems to be defunct.
-- None of the pieces in the database have an "incipient gesture".
chooseIncipientGesture :: Name -> [([String], [AnalysisLabel])]
chooseIncipientGesture _ = [(["incipience"], [])]
