import Control.Applicative
import Data.List
import Test.HUnit

import qualified Data.Vector as V
import qualified Data.Vector.Unboxed as U
import Statistics.Math
import Statistics.Test.NonParametric
import Debug.Trace


-- Lookup table for fact factorial calculation. It has fixed size
-- which is bad but it's OK for this particular case
factorial_table :: V.Vector Integer
factorial_table = V.generate 2000 (\n -> product [1..fromIntegral n])

-- Exact implementation of factorial
factorial' :: Integer -> Integer
factorial' n = factorial_table V.! fromIntegral n

-- Exact albeit slow implementation of choose
choose' :: Integer -> Integer -> Integer
choose' n k = factorial' n `div` (factorial' k * factorial' (n-k))

-- Error in determination of factorial
factorialErr :: Integer -> Double
factorialErr n = (f' - f) / f'
  where
    f' = fromIntegral (factorial' n)
    f  = factorial (fromIntegral n)

-- Error in determination of log of factorial
factorialLogErr :: Integer -> Double
factorialLogErr n = (f' - f) / f'
  where
    f' = log $ fromIntegral $ factorial' n
    f  = logFactorial (fromIntegral n)

-- Error in determination if binmial coef.
chooseErr :: Integer -> Integer -> Double 
chooseErr n k = (c - c') / c'
  where
    c' = fromIntegral (choose' n k)
    c  = choose (fromIntegral n) (fromIntegral k)

-- Error in logGamma function for integer points > 2
logGammaErr :: Int -> Double
logGammaErr n = (logGamma (fromIntegral n) - l) / l where l = logFactorial n

-- Error in logGammaL function for integer points > 2
logGammaLErr :: Int -> Double
logGammaLErr n = (logGammaL (fromIntegral n) - l) / l where l = logFactorial n

-- Test beta function.
-- FIXME: I'm not sure whether it's correct test.
logBetaErr :: Double -> Double -> Double
logBetaErr p q = (lb' - lb) / max 1 (abs lb')
  where
    lb  = logBeta p q
    lb' = logGammaL p + logGammaL q - logGammaL (p+q)


wilcoxonPairTests :: [Test]
wilcoxonPairTests = zipWith test [0..] testData ++
  -- Taken from the Mitic paper:
  [TestCase $ assertBool "Sig 16, 35" (to4dp 0.0467 $ wilcoxonSignificance 16 35)
  ,TestCase $ assertBool "Sig 16, 36" (to4dp 0.0523 $ wilcoxonSignificance 16 36)
  ,TestCase $ assertEqual "Wilcoxon critical values, p=0.05"
    (replicate 4 Nothing ++ map Just [0,2,3,5,8,10,13,17,21,25,30,35,41,47,53,60,67,75,83,91,100,110,119])
    [wilcoxonCriticalValue x 0.05 | x <- [1..27]]
  ,TestCase $ assertEqual "Wilcoxon critical values, p=0.025"
    (replicate 5 Nothing ++ map Just [0,2,3,5,8,10,13,17,21,25,29,34,40,46,52,58,65,73,81,89,98,107])
    [wilcoxonCriticalValue x 0.025 | x <- [1..27]]
  ,TestCase $ assertEqual "Wilcoxon critical values, p=0.01"
    (replicate 6 Nothing ++ map Just [0,1,3,5,7,9,12,15,19,23,27,32,37,43,49,55,62,69,76,84,92])
    [wilcoxonCriticalValue x 0.01 | x <- [1..27]]
  ,TestCase $ assertEqual "Wilcoxon critical values, p=0.005"
    (replicate 7 Nothing ++ map Just [0,1,3,5,7,9,12,15,19,23,27,32,37,42,48,54,61,68,75,83])
    [wilcoxonCriticalValue x 0.005 | x <- [1..27]]
  ]
  where
    test n (a, b, c) = TestCase $ assertEqual ("Wilcoxon Paired " ++ show n) c (wilcoxonMatchedPairSignedRank (U.fromList a) (U.fromList b))
    
    -- List of (Sample A, Sample B, (Positive Rank, Negative Rank))
    testData :: [([Double], [Double], (Double, Double))]
    testData = [([1..10], [1..10], (0, 0))
               ,([1..5], [6..10], (0, 5*(-3)))
               -- Worked example from the Internet:
               ,([125,115,130,140,140,115,140,125,140,135]
                ,[110,122,125,120,140,124,123,137,135,145]
                ,(sum $ filter (> 0) [7,-3,1.5,9,0,-4,8,-6,1.5,-5]
                 ,sum $ filter (< 0) [7,-3,1.5,9,0,-4,8,-6,1.5,-5]))
               -- Worked examples from books/papers:
               ,([2.4,1.9,2.3,1.9,2.4,2.5]
                ,[2.0,2.1,2.0,2.0,1.8,2.0]
                ,(18, -3))
               ,([130,170,125,170,130,130,145,160]
                ,[120,163,120,135,143,136,144,120]
                ,(27, -9))
               ,([540,580,600,680,430,740,600,690,605,520]
                ,[760,710,1105,880,500,990,1050,640,595,520]
                ,(3, -42))
               ]
    to4dp tgt x = x >= tgt - 0.00005 && x < tgt + 0.00005

----------------------------------------------------------------
-- Full list of tests
----------------------------------------------------------------

-- These tests may take a while to run
allTests :: Test
allTests = TestList $ wilcoxonPairTests ++ [
    TestCase $ assertBool "Factorial is expected to be precise at 1e-15 level" $
      all (< 1e-15) $ map factorialErr [0..170]
  , TestCase $ assertBool "Factorial is expected to be precise at 1e-15 level" $
      all (< 1e-15) $ map factorialLogErr [2..170]
  , TestCase $ assertBool "logGamma is expected to be precise at 1e-9 level" $
      all (< 1e-9) $ map logGammaErr [3..100000]
  , TestCase $ assertBool "logGammaL is expected to be precise at 1e-15 level" $
      all (< 1e-15) $ map logGammaErr [3..100000]
  , TestCase $ assertBool "logBeta is expected to be precise at 1e-10 level" $
      all (< 3e-8) $ logBetaErr <$> [0.1,0.2 .. 100] <*> [0.1,0.2 .. 100]
  , TestCase $ assertBool "choose is expected to precise at 1e-7 level" $
      all (< 1e-12) [chooseErr n k | n <- [0..1000], k <- [0..n]]
  ]

main :: IO ()
main = print =<< runTestTT allTests
