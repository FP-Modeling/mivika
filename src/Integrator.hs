{-# LANGUAGE BangPatterns #-}

module Integrator where

import Data.IORef
import Control.Monad.Trans


import Prelude hiding (Real)
import Types
import Dynamics
import Solver
import Utils
import Memo
           
--
-- Integral type
--

-- | The 'Integ' type represents an integral.
data Integ = Integ { initial :: Dynamics Real,   -- ^ The initial value.
                     cache   :: IORef (Dynamics Real),
                     result  :: IORef (Dynamics Real) }

data Integ' = Integ' { initial'     :: Dynamics Real,
                       computation' :: IORef (Dynamics Real) }

-- | Return the initial value.
initialize :: Dynamics a -> Dynamics a
initialize (Dynamics m) =
  Dynamics $ \ps ->
  if iteration (solver ps) == 0 && stage (solver ps) == 0 then
    m ps
  else
    let iv = interval ps
        sl = solver ps
    in m $ ps { time = iterToTime iv sl 0 0,
                solver = sl { iteration = 0,
                              stage = 0 }}

-- -- | Create a new integral with the specified initial value.
newInteg :: Dynamics Real -> Dynamics Integ
newInteg i = 
  do r1 <- liftIO $ newIORef $ initialize i 
     r2 <- liftIO $ newIORef $ initialize i 
     let integ = Integ { initial = i, 
                         cache   = r1,
                         result  = r2 }
         z = Dynamics $ \ps -> 
           do (Dynamics m) <- readIORef (result integ)
              m ps
     y <- memo interpolate z
     liftIO $ writeIORef (cache integ) y
     return integ

-- newInteg' :: Dynamics Real -> Dynamics Integ'
-- newInteg' i = 
--   do comp <- liftIO $ newIORef $ initD i 
--      let integ = Integ' { initial'     = i, 
--                           computation' = comp }
--      return integ

-- | Return the integral's value.
integValue :: Integ -> Dynamics Real
integValue integ = 
  Dynamics $ \ps ->
  do (Dynamics m) <- readIORef (cache integ)
     m ps

-- -- | Set the derivative for the integral.
integDiff :: Integ -> Dynamics Real -> Dynamics ()
integDiff integ diff =
  do let z = Dynamics $ \ps ->
           do y <- readIORef (cache integ) -- Give me past values
              let i = initial integ -- Give me initial value
              case method (solver ps) of -- Check the solver method
                Euler -> integEuler diff i y ps
                RungeKutta2 -> integRK2 diff i y ps
                RungeKutta4 -> integRK4 diff i y ps
     liftIO $ writeIORef (result integ) z -- This is the new computation now!

integEuler :: Dynamics Real
             -> Dynamics Real 
             -> Dynamics Real 
             -> Parameters -> IO Real
integEuler (Dynamics diff) (Dynamics i) (Dynamics y) ps =
  case iteration (solver ps) of
    0 -> 
      i ps
    n -> do 
      let iv  = interval ps
          sl  = solver ps
          ty  = iterToTime iv sl (n - 1) 0
          psy = ps { time = ty, solver = sl {iteration = n - 1, stage = 0} }
      a <- y psy
      b <- diff psy
      let !v = a + dt (solver ps) * b
      return v

integRK2 :: Dynamics Real
           -> Dynamics Real
           -> Dynamics Real
           -> Parameters -> IO Real
integRK2 (Dynamics f) (Dynamics i) (Dynamics y) ps =
  case stage (solver ps) of
    0 -> case iteration (solver ps) of
      0 ->
        i ps
      n -> do
        let iv = interval ps
            sl = solver ps
            ty = iterToTime iv sl (n - 1) 0
            t1 = ty
            t2 = iterToTime iv sl (n - 1) 1
            psy = ps { time = ty, solver = sl {iteration = n - 1, stage = 0 }}
            ps1 = psy
            ps2 = ps { time = t2, solver = sl {iteration = n - 1, stage = 1 }}
        vy <- y psy
        k1 <- f ps1
        k2 <- f ps2
        let !v = vy + dt sl / 2.0 * (k1 + k2)
        return v
    1 -> do
      let iv = interval ps
          sl = solver ps
          n  = iteration sl
          ty = iterToTime iv sl n 0
          t1 = ty
          psy = ps { time = ty, solver = sl {iteration = n, stage = 0 }}
          ps1 = psy
      vy <- y psy
      k1 <- f ps1
      let !v = vy + dt sl * k1
      return v
    _ -> 
      error "Incorrect stage: integ"

integRK4 :: Dynamics Real
           -> Dynamics Real
           -> Dynamics Real
           -> Parameters -> IO Real
integRK4 (Dynamics f) (Dynamics i) (Dynamics y) ps =
  case stage (solver ps) of
    0 -> case iteration (solver ps) of
      0 -> 
        i ps
      n -> do
        let iv = interval ps
            sl = solver ps
            ty = iterToTime iv sl (n - 1) 0
            t1 = ty
            t2 = iterToTime iv sl  (n - 1) 1
            t3 = iterToTime iv sl  (n - 1) 2
            t4 = iterToTime iv sl  (n - 1) 3
            psy = ps { time = ty, solver = sl {iteration = n - 1, stage = 0 }}
            ps1 = psy
            ps2 = ps { time = t2, solver = sl {iteration = n - 1, stage = 1 }}
            ps3 = ps { time = t3, solver = sl {iteration = n - 1, stage = 2 }}
            ps4 = ps { time = t4, solver = sl {iteration = n - 1, stage = 3 }}
        vy <- y psy
        k1 <- f ps1
        k2 <- f ps2
        k3 <- f ps3
        k4 <- f ps4
        let !v = vy + dt sl / 6.0 * (k1 + 2.0 * k2 + 2.0 * k3 + k4)
        return v
    1 -> do
      let iv = interval ps
          sl = solver ps
          n  = iteration sl
          ty = iterToTime iv sl n 0
          t1 = ty
          psy = ps { time = ty, solver = sl {iteration = n, stage = 0 }}
          ps1 = psy
      vy <- y psy
      k1 <- f ps1
      let !v = vy + dt sl / 2.0 * k1
      return v
    2 -> do
      let iv = interval ps
          sl = solver ps
          n  = iteration sl
          ty = iterToTime iv sl n 0
          t2 = iterToTime iv sl n 1
          psy = ps { time = ty, solver = sl {iteration = n, stage = 0 }}
          ps2 = ps { time = t2, solver = sl {iteration = n, stage = 1 }}
      vy <- y psy
      k2 <- f ps2
      let !v = vy + dt sl / 2.0 * k2
      return v
    3 -> do
      let iv = interval ps
          sl = solver ps
          n  = iteration sl
          ty = iterToTime iv sl n 0
          t3 = iterToTime iv sl n 2
          psy = ps { time = ty, solver = sl {iteration = n, stage = 0 }}
          ps3 = ps { time = t3, solver = sl {iteration = n, stage = 2 }}
      vy <- y psy
      k3 <- f ps3
      let !v = vy + dt sl * k3
      return v
    _ -> 
      error "Incorrect stase: integ"

