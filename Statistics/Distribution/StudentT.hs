{-# LANGUAGE DeriveDataTypeable, DeriveGeneric, CPP #-}
-- |
-- Module    : Statistics.Distribution.StudentT
-- Copyright : (c) 2011 Aleksey Khudyakov
-- License   : BSD3
--
-- Maintainer  : bos@serpentine.com
-- Stability   : experimental
-- Portability : portable
--
-- Student-T distribution
module Statistics.Distribution.StudentT (
    StudentT
  , studentT
  , studentTndf
  , studentTUnstandardized
  ) where

import Data.Binary (Binary)
import Data.Data (Data, Typeable)
import GHC.Generics (Generic)
import qualified Statistics.Distribution as D
import Statistics.Distribution.Transform (LinearTransform (..))
import Numeric.SpecFunctions (
  logBeta, incompleteBeta, invIncompleteBeta, digamma)
#if !MIN_VERSION_binary(0, 6, 0)
import Data.Binary (put, get)
#endif

-- | Student-T distribution
newtype StudentT = StudentT { studentTndf :: Double }
                   deriving (Eq, Show, Read, Typeable, Data, Generic)

instance Binary StudentT where
#if !MIN_VERSION_binary(0, 6, 0)
    put = put . studentTndf
    get = fmap StudentT get
#endif

-- | Create Student-T distribution. Number of parameters must be positive.
studentT :: Double -> StudentT
studentT ndf
  | ndf > 0   = StudentT ndf
  | otherwise = modErr "studentT" "non-positive number of degrees of freedom"

instance D.Distribution StudentT where
  cumulative = cumulative

instance D.ContDistr StudentT where
  density    d@(StudentT ndf) x = exp (logDensityUnscaled d x) / sqrt ndf
  logDensity d@(StudentT ndf) x = logDensityUnscaled d x - log (sqrt ndf)
  quantile = quantile

cumulative :: StudentT -> Double -> Double
cumulative (StudentT ndf) x
  | x > 0     = 1 - 0.5 * ibeta
  | otherwise = 0.5 * ibeta
  where
    ibeta = incompleteBeta (0.5 * ndf) 0.5 (ndf / (ndf + x*x))

logDensityUnscaled :: StudentT -> Double -> Double
logDensityUnscaled (StudentT ndf) x =
    log (ndf / (ndf + x*x)) * (0.5 * (1 + ndf)) - logBeta 0.5 (0.5 * ndf)

quantile :: StudentT -> Double -> Double
quantile (StudentT ndf) p
  | p >= 0 && p <= 1 =
    let x = invIncompleteBeta (0.5 * ndf) 0.5 (2 * min p (1 - p))
    in case sqrt $ ndf * (1 - x) / x of
         r | p < 0.5   -> -r
           | otherwise -> r
  | otherwise = modErr "quantile" $ "p must be in [0,1] range. Got: "++show p


instance D.MaybeMean StudentT where
  maybeMean (StudentT ndf) | ndf > 1   = Just 0
                           | otherwise = Nothing

instance D.MaybeVariance StudentT where
  maybeVariance (StudentT ndf) | ndf > 2   = Just $! ndf / (ndf - 2)
                               | otherwise = Nothing

instance D.Entropy StudentT where
  entropy (StudentT ndf) =
    0.5 * (ndf+1) * (digamma ((1+ndf)/2) - digamma(ndf/2))
    + log (sqrt ndf) 
    + logBeta (ndf/2) 0.5

instance D.MaybeEntropy StudentT where
  maybeEntropy = Just . D.entropy

instance D.ContGen StudentT where
  genContVar = D.genContinous

-- | Create an unstandardized Student-t distribution.
studentTUnstandardized :: Double -- ^ Number of degrees of freedom
                       -> Double -- ^ Central value (0 for standard Student T distribution)
                       -> Double -- ^ Scale parameter
                       -> LinearTransform StudentT
studentTUnstandardized ndf mu sigma
  | sigma > 0 = LinearTransform mu sigma $ studentT ndf
  | otherwise = modErr "studentTUnstandardized" $ "sigma must be > 0. Got: " ++ show sigma

modErr :: String -> String -> a
modErr fun msg = error $ "Statistics.Distribution.StudentT." ++ fun ++ ": " ++ msg
