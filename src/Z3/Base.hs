{-# LANGUAGE DeriveDataTypeable         #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternGuards              #-}
{-# LANGUAGE NamedFieldPuns             #-}
{-# LANGUAGE ScopedTypeVariables        #-}

-- |
-- Module    : Z3.Base
-- Copyright : (c) Iago Abal, 2012-2015
--             (c) David Castro, 2012-2015
-- License   : BSD3
-- Maintainer: Iago Abal <mail@iagoabal.eu>,
--             David Castro <david.castro.dcp@gmail.com>
--
-- Low-level bindings to Z3 API.
--
-- There is (mostly) a one-to-one correspondence with Z3 C API, thus see
-- <http://z3prover.github.io/api/html/group__capi.html>
-- for further details.

{- HACKING

Add here the IO-based wrapper for a new Z3 API function:

* Take a look to a few others API functions and follow the same coding style.
    * 2-space wide indentation, no tabs.
    * No trailing spaces, please.
    * ...
* Place the API function in the right section, according to the Z3's API documentation.
* Annotate the API function with a short but concise haddock comment.
    * Look at the Z3 API documentation for inspiration.
* Add the API function to the module export list, (only) if needed.

This should be straightforward for most cases using [MARSHALLING HELPERS].

Reference counting
------------------

When an object is returned by the C API, we:
* increment its reference counter (if applicable),
* wrap the pointer into a ForeignPtr, and
* install a finalizer to decrement the counter.

Objects with explicit /delete/ functions, instead of reference
counters, are handled analogously.In this way, we move memory
management into the GC.

Remarkably, a Z3_context cannot be deleted until we "free" every
object depending on it. But ForeignPtr finalizers do not provide
any ordering guarantee, and it's not possible to establish
dependencies between finalizers. Thus, we /count references/ to
a Z3_context and only delete it when this count reaches /zero/.

-}

module Z3.Base (

  -- * Types
    Config
  , Context
  , Symbol
  , AST
  , Sort
  , TupleType(..)
  , FuncDecl
  , App
  , Pattern
  , Constructor
  , Model
  , FuncInterp
  , FuncEntry
  , Params
  , Solver
  , SortKind(..)
  , ASTKind(..)
  , Tactic
  , ApplyResult
  , Goal
  -- ** Satisfiability result
  , Result(..)

  -- * Algebraic Numbers
  , algebraicIsValue
  , algebraicIsPos
  , algebraicIsNeg
  , algebraicIsZero
  , algebraicSign
  , algebraicAdd
  , algebraicSub
  , algebraicMul
  , algebraicDiv
  , algebraicRoot
  , algebraicPower
  , algebraicLt
  , algebraicGt
  , algebraicLe
  , algebraicGe
  , algebraicEq
  , algebraicNeq
  , algebraicRoots
  , algebraicEval

  -- * Global Parameters
  , globalParamSet
  , globalParamResetAll
  , globalParamGet

  -- * Create configuration
  , mkConfig
  , delConfig
  , setParamValue
  -- ** Helpers
  , withConfig

  -- * Create context
  , mkContext
  , withContext

  -- * Parameters
  , mkParams
  , paramsSetBool
  , paramsSetUInt
  , paramsSetDouble
  , paramsSetSymbol
  , paramsToString

  -- * Symbols
  , mkIntSymbol
  , mkStringSymbol

  -- * Sorts
  , mkUninterpretedSort
  , mkBoolSort
  , mkIntSort
  , mkRealSort
  , mkBvSort
  , mkFiniteDomainSort
  , mkArraySort
  , mkArraySortN
  , mkTupleSort
  , mkTupleType
  , mkTuple
  , mkIndexTuple
  , mkProjTuple
  , mkEnumerationSort
  , mkListSort
  , mkConstructor
  , mkDatatype
  , mkDatatypes
  , mkSetSort

  -- * Constants and Applications
  , mkFuncDecl
  , mkApp
  , mkConst
  , mkFreshFuncDecl
  , mkFreshConst
  , mkRecFuncDecl
  , addRecDef
  -- ** Helpers
  , mkVar
  , mkBoolVar
  , mkRealVar
  , mkIntVar
  , mkBvVar
  , mkFreshVar
  , mkFreshBoolVar
  , mkFreshRealVar
  , mkFreshIntVar
  , mkFreshBvVar

  -- * Propositional Logic and Equality
  , mkTrue
  , mkFalse
  , mkEq
  , mkNot
  , mkIte
  , mkIff
  , mkImplies
  , mkXor
  , mkAnd
  , mkOr
  , mkDistinct
  , mkDistinct1
  -- ** Helpers
  , mkBool

  -- * Arithmetic: Integers and Reals
  , mkAdd
  , mkMul
  , mkSub
  , mkSub1
  , mkUnaryMinus
  , mkDiv
  , mkMod
  , mkRem
  , mkPower
  , mkLt
  , mkLe
  , mkGt
  , mkGe
  , mkInt2Real
  , mkReal2Int
  , mkIsInt

  -- * Bit-vectors
  , mkBvnot
  , mkBvredand
  , mkBvredor
  , mkBvand
  , mkBvor
  , mkBvxor
  , mkBvnand
  , mkBvnor
  , mkBvxnor
  , mkBvneg
  , mkBvadd
  , mkBvsub
  , mkBvmul
  , mkBvudiv
  , mkBvsdiv
  , mkBvurem
  , mkBvsrem
  , mkBvsmod
  , mkBvult
  , mkBvslt
  , mkBvule
  , mkBvsle
  , mkBvuge
  , mkBvsge
  , mkBvugt
  , mkBvsgt
  , mkConcat
  , mkExtract
  , mkSignExt
  , mkZeroExt
  , mkRepeat
  , mkBvshl
  , mkBvlshr
  , mkBvashr
  , mkRotateLeft
  , mkRotateRight
  , mkExtRotateLeft
  , mkExtRotateRight
  , mkInt2bv
  , mkBv2int
  , mkBvnegNoOverflow
  , mkBvaddNoOverflow
  , mkBvaddNoUnderflow
  , mkBvsubNoOverflow
  , mkBvsubNoUnderflow
  , mkBvmulNoOverflow
  , mkBvmulNoUnderflow
  , mkBvsdivNoOverflow

  -- * Arrays
  , mkSelect
  , mkStore
  , mkConstArray
  , mkMap
  , mkArrayDefault

  -- * Sets
  , mkEmptySet
  , mkFullSet
  , mkSetAdd
  , mkSetDel
  , mkSetUnion
  , mkSetIntersect
  , mkSetDifference
  , mkSetComplement
  , mkSetMember
  , mkSetSubset

  -- * Numerals
  , mkNumeral
  , mkReal
  , mkInt
  , mkUnsignedInt
  , mkInt64
  , mkUnsignedInt64
  -- ** Helpers
  , mkIntegral
  , mkRational
  , mkFixed
  , mkRealNum
  , mkInteger
  , mkIntNum
  , mkBitvector
  , mkBvNum

  -- * Sequences and regular expressions
  , mkSeqSort
  , isSeqSort
  , mkReSort
  , isReSort
  , mkStringSort
  , isStringSort
  , mkString
  , isString
  , getString
  , mkSeqEmpty
  , mkSeqUnit
  , mkSeqConcat
  , mkSeqPrefix
  , mkSeqSuffix
  , mkSeqContains
  , mkStrLt
  , mkStrLe
  , mkSeqExtract
  , mkSeqReplace
  , mkSeqAt
  , mkSeqNth
  , mkSeqLength
  , mkSeqIndex
  , mkStrToInt
  , mkIntToStr
  , mkSeqToRe
  , mkSeqInRe
  , mkRePlus
  , mkReStar
  , mkReOption
  , mkReUnion
  , mkReConcat
  , mkReRange
  , mkReLoop
  , mkReIntersect
  , mkReComplement
  , mkReEmpty
  , mkReFull

  -- * Quantifiers
  , mkPattern
  , mkBound
  , mkForall
  , mkForallW
  , mkExists
  , mkExistsW
  , mkForallConst
  , mkForallWConst
  , mkExistsConst
  , mkExistsWConst

  -- * Accessors
  , getSymbolString
  , isEqSort
  , getSortName
  , sortToAst
  , getSortId
  , getSortKind
  , getBvSortSize
  , getFiniteDomainSortSize
  , getTupleSortMkDecl
  , getTupleSortNumFields
  , getTupleSortFieldDecl
  , getDatatypeSortConstructors
  , getDatatypeSortRecognizers
  , getDatatypeSortConstructorAccessors
  , mkAtMost
  , mkAtLeast
  , getDeclName
  , getArity
  , getDomain
  , getRange
  , getDeclNumParameters
  , appToAst
  , getAppDecl
  , getAppNumArgs
  , getAppArg
  , getAppArgs
  , getSort
  , isWellSorted
  , getArraySortDomain
  , getArraySortRange
  , getBoolValue
  , getAstKind
  , isApp
  , toApp
  , getNumeralString
  , getNumerator
  , getDenominator
  , simplify
  , simplifyEx
  , getIndexValue
  , isQuantifierForall
  , isQuantifierExists
  , getQuantifierWeight
  , getQuantifierNumPatterns
  , getQuantifierPatternAST
  , getQuantifierPatterns
  , getQuantifierNumNoPatterns
  , getQuantifierNoPatternAST
  , getQuantifierNoPatterns
  , getQuantifierNumBound
  , getQuantifierBoundName
  , getQuantifierBoundSort
  , getQuantifierBoundVars
  , getQuantifierBody
  -- ** Helpers
  , getBool
  , getInt
  , getReal

  -- * Modifiers
  , substituteVars
  , substitute

  -- * Models
  , modelTranslate
  , modelEval
  , evalArray
  , getConstInterp
  , getFuncInterp
  , hasInterp
  , numConsts
  , numFuncs
  , getConstDecl
  , getFuncDecl
  , getConsts
  , getFuncs
  , isAsArray
  , isEqAST
  , addFuncInterp
  , addConstInterp
  , getAsArrayFuncDecl
  , funcInterpGetNumEntries
  , funcInterpGetEntry
  , funcInterpGetElse
  , funcInterpGetArity
  , funcEntryGetValue
  , funcEntryGetNumArgs
  , funcEntryGetArg
  , modelToString
  , showModel
  -- ** Helpers
  , EvalAst
  , eval
  , evalBool
  , evalInt
  , evalReal
  , evalBv
  , mapEval
  , evalT
  , FuncModel (..)
  , evalFunc

  -- * Tactics
  , mkTactic
  , andThenTactic
  , orElseTactic
  , skipTactic
  , tryForTactic
  , tacticUsingParams
  , repeatTactic
  , mkQuantifierEliminationTactic
  , mkAndInverterGraphTactic
  , applyTactic
  , applyResultToString
  , getApplyResultNumSubgoals
  , getApplyResultSubgoal
  , getApplyResultSubgoals
  , mkGoal
  , goalAssert
  , getGoalSize
  , getGoalFormula
  , getGoalFormulas
  , goalToString
  , convertModel

  -- * String Conversion
  , ASTPrintMode(..)
  , setASTPrintMode
  , astToString
  , patternToString
  , sortToString
  , funcDeclToString
  , benchmarkToSMTLibString

  -- * Parser interface
  , parseSMTLib2String
  , parseSMTLib2File
  , evalSMTLib2String

  -- * Error Handling
  , Z3Error(..)
  , Z3ErrorCode(..)

  -- * Miscellaneous
  , Version(..)
  , getVersion

  -- * Fixedpoint
  , Fixedpoint (..)
  , mkFixedpoint
  , fixedpointAddRule
  , fixedpointSetParams
  , fixedpointRegisterRelation
  , fixedpointQueryRelations
  , fixedpointGetAnswer
  , fixedpointGetAssertions

  -- * Floating-Point Arithmetic
  , mkFpaRoundingModeSort
  , mkFpaRoundNearestTiesToEven
  , mkFpaRne
  , mkFpaRoundNearestTiesToAway
  , mkFpaRna
  , mkFpaRoundTowardPositive
  , mkFpaRtp
  , mkFpaRoundTowardNegative
  , mkFpaRtn
  , mkFpaRoundTowardZero
  , mkFpaRtz
  , mkFpaSort
  , mkFpaSortHalf
  , mkFpaSort16
  , mkFpaSortSingle
  , mkFpaSort32
  , mkFpaSortDouble
  , mkFpaSort64
  , mkFpaSortQuadruple
  , mkFpaSort128
  , mkFpaNaN
  , mkFpaInf
  , mkFpaZero
  , mkFpaFp
  , mkFpaNumeralFloat
  , mkFpaNumeralDouble
  , mkFpaNumeralInt
  , mkFpaNumeralIntUInt
  , mkFpaNumeralInt64UInt64
  , mkFpaAbs
  , mkFpaNeg
  , mkFpaAdd
  , mkFpaSub
  , mkFpaMul
  , mkFpaDiv
  , mkFpaFma
  , mkFpaSqrt
  , mkFpaRem
  , mkFpaRoundToIntegral
  , mkFpaMin
  , mkFpaMax
  , mkFpaLeq
  , mkFpaLt
  , mkFpaGeq
  , mkFpaGt
  , mkFpaEq
  , mkFpaIsNormal
  , mkFpaIsSubnormal
  , mkFpaIsZero
  , mkFpaIsInfinite
  , mkFpaIsNaN
  , mkFpaIsNegative
  , mkFpaIsPositive
  , mkFpaToFpBv
  , mkFpaToFpFloat
  , mkFpaToFpReal
  , mkFpaToFpSigned
  , mkFpaToFpUnsigned
  , mkFpaToUbv
  , mkFpaToSbv
  , mkFpaToReal

  -- * Z3-specific floating-point extensions
  , fpaGetEbits
  , fpaGetSbits
  , fpaIsNumeralNaN
  , fpaIsNumeralInf
  , fpaIsNumeralZero
  , fpaIsNumeralNormal
  , fpaIsNumeralSubnormal
  , fpaIsNumeralPositive
  , fpaIsNumeralNegative
  , fpaGetNumeralSignBv
  , fpaGetNumeralSignificandBv
  , fpaGetNumeralSignificandString
  , fpaGetNumeralExponentString
  , fpaGetNumeralExponentBv
  , mkFpaToIEEEBv
  , mkFpaToFpIntReal

  -- * Optimization
  , Optimize (..)
  , mkOptimize
  , optimizeAssert
  , optimizeAssertAndTrack
  , optimizeAssertSoft
  , optimizeMaximize
  , optimizeMinimize
  , optimizePush
  , optimizePop
  , optimizeCheck
  , optimizeGetReasonUnknown
  , optimizeGetModel
  , optimizeGetUnsatCore
  , optimizeSetParams
  , optimizeGetLower
  , optimizeGetUpper
  , optimizeGetUpperAsVector
  , optimizeGetLowerAsVector
  , optimizeToString
  , optimizeFromString
  , optimizeFromFile
  , optimizeGetHelp
  , optimizeGetAssertions
  , optimizeGetObjectives

  -- * Solvers
  , Logic(..)
  , mkSolver
  , mkSimpleSolver
  , mkSolverForLogic
  , solverGetHelp
  , solverSetParams
  , solverPush
  , solverPop
  , solverReset
  , solverGetNumScopes
  , solverAssertCnstr
  , solverAssertAndTrack
  , solverFromFile
  , solverFromString
  , solverGetAssertions
  , solverCheck
  , solverCheckAssumptions
  , solverGetModel
  , solverGetProof
  , solverGetUnsatCore
  , solverGetReasonUnknown
  , solverToString
  -- ** Helpers
  , solverCheckAndGetModel
  ) where

import Z3.Base.C
import Z3.Common
import Z3.RLock ( RLock, new, with)

import Control.Applicative ( (<$>), (<*>), (<*), pure )
import Control.Exception ( Exception, bracket, throw )
import Control.Monad ( join, when, forM )
import Data.Fixed ( Fixed, HasResolution )
import Data.Foldable ( Foldable (..) )
import Data.Int
import Data.IORef ( IORef, newIORef, atomicModifyIORef' )
import Data.List.NonEmpty (NonEmpty (..), nonEmpty)
import Data.Maybe ( fromJust )
import Data.Ratio ( numerator, denominator, (%) )
import Data.Traversable ( Traversable )
import qualified Data.Traversable as T
import Data.Typeable ( Typeable )
import Data.Word
import Foreign hiding ( newForeignPtr )
import Foreign.Storable ( peek )
import Foreign.C
  ( CFloat, CDouble, CInt, CUInt, CLong, CULong, CLLong, CULLong, CString
  , peekCString
  , withCString )
import Foreign.Concurrent

---------------------------------------------------------------------
-- * Types

-- | A Z3 /configuration object/.
newtype Config = Config { unConfig :: Ptr Z3_config }
    deriving Eq

-- | A Z3 /logical context/.
data Context =
    Context {
      unContext :: ForeignPtr Z3_context
    , refCount  :: !(IORef Word)
    , lock :: RLock
    }
    deriving Eq

-- | A Z3 /symbol/.
--
-- Used to name types, constants and functions.
newtype Symbol = Symbol { unSymbol :: Ptr Z3_symbol }
    deriving (Eq, Ord, Show, Storable)

-- | A Z3 /AST node/.
--
-- This is the data-structure used in Z3 to represent terms, formulas and types.
newtype AST = AST { unAST :: ForeignPtr Z3_ast }
    deriving (Eq, Ord, Show, Typeable)

-- | A kind of AST representing /types/.
newtype Sort = Sort { unSort :: ForeignPtr Z3_sort }
    deriving (Eq, Ord, Show)

-- | A sort representing named tuples with associated functions
data TupleType
  = TupleType {
      tupleSort :: Sort
    , tupleCons :: FuncDecl                   -- ^ constructor function
    , namedTupleProjs :: [(String, FuncDecl)] -- ^ projection functions
    }

tupleProjs :: TupleType -> [FuncDecl]
tupleProjs = map snd . namedTupleProjs

-- | A kind of AST representing function symbols.
newtype FuncDecl = FuncDecl { unFuncDecl :: ForeignPtr Z3_func_decl }
    deriving (Eq, Ord, Show, Typeable)

-- | A kind of AST representing constant and function declarations.
newtype App = App { unApp :: ForeignPtr Z3_app }
    deriving (Eq, Ord, Show)

-- | A kind of AST representing pattern and multi-patterns to
-- guide quantifier instantiation.
newtype Pattern = Pattern { unPattern :: ForeignPtr Z3_pattern }
    deriving (Eq, Ord, Show)

-- | A type contructor for a (recursive) datatype.
newtype Constructor = Constructor { unConstructor :: ForeignPtr Z3_constructor }
    deriving (Eq, Ord, Show)

-- | A list of type contructors for (recursive) datatypes.
newtype ConstructorList = ConstructorList { unConstructorList :: ForeignPtr Z3_constructor_list }
    deriving (Eq, Ord, Show)

-- | A model for the constraints asserted into the logical context.
newtype Model = Model { unModel :: ForeignPtr Z3_model }
    deriving Eq

-- | An interpretation of a function in a model.
newtype FuncInterp = FuncInterp { unFuncInterp :: ForeignPtr Z3_func_interp }
    deriving Eq

-- | Representation of the value of a 'Z3_func_interp' at a particular point.
newtype FuncEntry = FuncEntry { unFuncEntry :: ForeignPtr Z3_func_entry }
    deriving Eq

-- | A tactic
newtype Tactic = Tactic { unTactic :: ForeignPtr Z3_tactic }
    deriving Eq

-- | A goal (aka problem)
newtype Goal = Goal { unGoal :: ForeignPtr Z3_goal }
    deriving Eq

-- | A result of applying a tactic
newtype ApplyResult = ApplyResult { unApplyResult :: ForeignPtr Z3_apply_result }
    deriving Eq

-- | A Z3 parameter set.
--
-- Starting at Z3 4.0, parameter sets are used to configure many components
-- such as: simplifiers, tactics, solvers, etc.
newtype Params = Params { unParams :: ForeignPtr Z3_params }
    deriving Eq

-- | A Z3 solver engine.
--
-- A(n) (incremental) solver, possibly specialized by a particular tactic
-- or logic.
newtype Solver = Solver { unSolver :: ForeignPtr Z3_solver }
    deriving Eq

-- | Result of a satisfiability check.
--
-- This corresponds to the /z3_lbool/ type in the C API.
data Result
    = Sat
    | Unsat
    | Undef
    deriving (Eq, Ord, Read, Show)

-- | Different kinds of Z3 types.
data SortKind
    = Z3_UNINTERPRETED_SORT
    | Z3_BOOL_SORT
    | Z3_INT_SORT
    | Z3_REAL_SORT
    | Z3_BV_SORT
    | Z3_ARRAY_SORT
    | Z3_DATATYPE_SORT
    | Z3_RELATION_SORT
    | Z3_FINITE_DOMAIN_SORT
    | Z3_FLOATING_POINT_SORT
    | Z3_ROUNDING_MODE_SORT
    | Z3_UNKNOWN_SORT
    deriving (Eq, Show)

-- | Different kinds of Z3 AST nodes.
data ASTKind
    = Z3_NUMERAL_AST
    | Z3_APP_AST
    | Z3_VAR_AST
    | Z3_QUANTIFIER_AST
    | Z3_SORT_AST
    | Z3_FUNC_DECL_AST
    | Z3_UNKNOWN_AST
    deriving (Eq, Show)


---------------------------------------------------------------------
-- * Algebraic Numbers

algebraicIsValue :: Context -> AST -> IO Bool
algebraicIsValue = liftFun1 z3_algebraic_is_value


algebraicIsPos :: Context -> AST -> IO Bool
algebraicIsPos = liftFun1 z3_algebraic_is_pos

algebraicIsNeg :: Context -> AST -> IO Bool
algebraicIsNeg = liftFun1 z3_algebraic_is_neg

algebraicIsZero :: Context -> AST -> IO Bool
algebraicIsZero = liftFun1 z3_algebraic_is_zero

algebraicSign :: Context -> AST -> IO Int
algebraicSign = liftFun1 z3_algebraic_sign

algebraicAdd :: Context -> AST -> AST -> IO AST
algebraicAdd = liftFun2 z3_algebraic_add

algebraicSub :: Context -> AST -> AST -> IO AST
algebraicSub = liftFun2 z3_algebraic_sub

algebraicMul :: Context -> AST -> AST -> IO AST
algebraicMul = liftFun2 z3_algebraic_mul

algebraicDiv :: Context -> AST -> AST -> IO AST
algebraicDiv = liftFun2 z3_algebraic_div

algebraicRoot :: Context -> AST -> Int -> IO AST
algebraicRoot = liftFun2 z3_algebraic_root

algebraicPower :: Context -> AST -> Int -> IO AST
algebraicPower = liftFun2 z3_algebraic_power

algebraicLt :: Context -> AST -> AST -> IO Bool
algebraicLt = liftFun2 z3_algebraic_lt

algebraicGt :: Context -> AST -> AST -> IO Bool
algebraicGt = liftFun2 z3_algebraic_gt

algebraicLe :: Context -> AST -> AST -> IO Bool
algebraicLe = liftFun2 z3_algebraic_le

algebraicGe :: Context -> AST -> AST -> IO Bool
algebraicGe = liftFun2 z3_algebraic_ge

algebraicEq :: Context -> AST -> AST -> IO Bool
algebraicEq = liftFun2 z3_algebraic_eq

algebraicNeq :: Context -> AST -> AST -> IO Bool
algebraicNeq = liftFun2 z3_algebraic_neq

algebraicRoots :: Context -> AST -> [AST] -> IO [AST]
algebraicRoots ctx p args = marshal z3_algebraic_roots ctx $ \f ->
  h2c p $ \pPtr ->
    marshalArrayLen args $ \argsNum argsArr ->
      f pPtr argsNum argsArr

algebraicEval :: Context -> AST -> [AST] -> IO Int
algebraicEval ctx p args = marshal z3_algebraic_eval ctx $ \f ->
  h2c p $ \pPtr ->
    marshalArrayLen args $ \argsNum argsArr ->
      f pPtr argsNum argsArr

---------------------------------------------------------------------
-- * Global Parameters

globalParamSet :: String -> String -> IO ()
globalParamSet param value =
  withCString param $ \cParam ->
    withCString value $ \cValue ->
      z3_global_param_set cParam cValue

globalParamResetAll :: IO ()
globalParamResetAll = z3_global_param_reset_all

globalParamGet :: String -> IO (Maybe String)
globalParamGet param =
  withCString param $ \cParam ->
    alloca $ \cValuePtr ->
      do success <- z3_global_param_get cParam cValuePtr
         returnValueToMaybe success $ peekCString =<< peek cValuePtr

---------------------------------------------------------------------
-- * Create configuration

-- | Create a configuration.
--
-- See 'withConfig'.
mkConfig :: IO Config
mkConfig = Config <$> z3_mk_config

-- | Delete a configuration.
--
-- See 'withConfig'.
delConfig :: Config -> IO ()
delConfig = z3_del_config . unConfig

-- | Set a configuration parameter.
setParamValue :: Config -> String -> String -> IO ()
setParamValue cfg s1 s2 =
  withCString s1  $ \cs1 ->
    withCString s2  $ \cs2 ->
      z3_set_param_value (unConfig cfg) cs1 cs2

-------------------------------------------------
-- ** Helpers

-- | Run a computation using a temporally created configuration.
--
-- Note that the configuration object can be thrown away once
-- it has been used to create the Z3 'Context'.
withConfig :: (Config -> IO a) -> IO a
withConfig = bracket mkConfig delConfig

---------------------------------------------------------------------
-- Create context

mkContextWith :: (Ptr Z3_config -> IO (Ptr Z3_context)) -> Config -> IO Context
mkContextWith mkCtx cfg = do
  ctxPtr <- mkCtx (unConfig cfg)
  z3_set_error_handler ctxPtr nullFunPtr
  count <- newIORef 1
  Context <$> newForeignPtr ctxPtr (contextDecRef ctxPtr count)
          <*> pure count
          <*> Z3.RLock.new

-- | Create a context using the given configuration.
--
-- /Z3_del_context/ is called by Haskell's garbage collector before
-- freeing the 'Context' object.
mkContext :: Config -> IO Context
mkContext = mkContextWith z3_mk_context_rc

-- TODO: Z3_update_param_value
-- TODO: Z3_interrupt

-------------------------------------------------
-- Reference counting of Context

contextIncRef :: Context -> IO ()
contextIncRef ctx = atomicModifyIORef' (refCount ctx) $ \n ->
  (n+1, ())

contextDecRef :: Ptr Z3_context -> IORef Word -> IO ()
contextDecRef ctxPtr count = join $ atomicModifyIORef' count $ \n ->
  if n > 1
    then (n-1, return ())
    else (  0, z3_del_context ctxPtr)

---------------------------------------------------------------------
-- Parameters

-- | Create a Z3 (empty) parameter set.
--
-- Starting at Z3 4.0, parameter sets are used to configure many components
-- such as: simplifiers, tactics, solvers, etc.
mkParams :: Context -> IO Params
mkParams = liftFun0 z3_mk_params

-- | Add a Boolean parameter /k/ with value /v/ to the parameter set /p/.
paramsSetBool :: Context -> Params -> Symbol -> Bool -> IO ()
paramsSetBool = liftFun3 z3_params_set_bool

-- | Add a unsigned parameter /k/ with value /v/ to the parameter set /p/.
paramsSetUInt :: Context -> Params -> Symbol -> Word -> IO ()
paramsSetUInt = liftFun3 z3_params_set_uint

-- | Add a double parameter /k/ with value /v/ to the parameter set /p/.
paramsSetDouble :: Context -> Params -> Symbol -> Double -> IO ()
paramsSetDouble = liftFun3 z3_params_set_double

-- | Add a symbol parameter /k/ with value /v/ to the parameter set /p/.
paramsSetSymbol :: Context -> Params -> Symbol -> Symbol -> IO ()
paramsSetSymbol = liftFun3 z3_params_set_symbol

-- | Convert a parameter set into a string.
--
-- This function is mainly used for printing the contents of a parameter set.
paramsToString :: Context -> Params -> IO String
paramsToString = liftFun1 z3_params_to_string

-- TODO: Z3_params_validate

---------------------------------------------------------------------
-- Parameter Descriptions

-- TODO

---------------------------------------------------------------------
-- Symbols

-- | Create a Z3 symbol using an integer.
--
-- @mkIntSymbol c i@ /requires/ @0 <= i < 2^30@
mkIntSymbol :: Integral int => Context -> int -> IO Symbol
mkIntSymbol c i
  | 0 <= i && i <= 2^(30::Int)-1
  = liftFun1 z3_mk_int_symbol c i
  | otherwise
  = error "Z3.Base.mkIntSymbol: invalid range"

-- | Create a Z3 symbol using a 'String'.
mkStringSymbol :: Context -> String -> IO Symbol
mkStringSymbol = liftFun1 z3_mk_string_symbol

---------------------------------------------------------------------
-- Sorts

-- | Create a free (uninterpreted) type using the given name (symbol).
--
-- Two free types are considered the same iff the have the same name.
mkUninterpretedSort :: Context -> Symbol -> IO Sort
mkUninterpretedSort = liftFun1 z3_mk_uninterpreted_sort

-- | Create the /boolean/ type.
--
-- This type is used to create propositional variables and predicates.
mkBoolSort :: Context -> IO Sort
mkBoolSort = liftFun0 z3_mk_bool_sort

-- | Create the /integer/ type.
--
-- This is the type of arbitrary precision integers.
-- A machine integer can be represented using bit-vectors, see 'mkBvSort'.
mkIntSort :: Context -> IO Sort
mkIntSort = liftFun0 z3_mk_int_sort

-- | Create the /real/ type.
--
-- This type is not a floating point number.
-- Z3 does not have support for floating point numbers yet.
mkRealSort :: Context -> IO Sort
mkRealSort = liftFun0 z3_mk_real_sort

-- | Create a bit-vector type of the given size.
--
-- This type can also be seen as a machine integer.
--
-- @mkBvSort c sz@ /requires/ @sz >= 0@
mkBvSort :: Integral int => Context -> int -> IO Sort
mkBvSort c i
  | i >= 0    = liftFun1 z3_mk_bv_sort c i
  | otherwise = error "Z3.Base.mkBvSort: negative size"

-- | Create a finite-domain type.
mkFiniteDomainSort :: Context -> Symbol -> Word64 -> IO Sort
mkFiniteDomainSort = liftFun2 z3_mk_finite_domain_sort

-- | Create an array type
--
-- We usually represent the array type as: [domain -> range].
-- Arrays are usually used to model the heap/memory in software verification.
mkArraySort :: Context -> Sort -> Sort -> IO Sort
mkArraySort = liftFun2 z3_mk_array_sort

-- | Create an array type with N arguments.
mkArraySortN :: Context -> [Sort] -> Sort -> IO Sort
mkArraySortN ctx argSorts rangeSort = marshal z3_mk_array_sort_n ctx $ \f ->
  marshalArrayLen argSorts $ \nArgs argSortsPtr ->
    h2c rangeSort $ \rangeSortPtr ->
      f nArgs argSortsPtr rangeSortPtr

-- | Create a tuple type
--
-- A tuple with n fields has a constructor and n projections.
-- This function will also declare the constructor and projection functions.
mkTupleSort :: Context                         -- ^ Context
            -> Symbol                          -- ^ Name of the sort
            -> [(Symbol, Sort)]                -- ^ Name and sort of each field
            -> IO (Sort, FuncDecl, [FuncDecl]) -- ^ Resulting sort, and function
                                               -- declarations for the
                                               -- constructor and projections.
mkTupleSort c sym symSorts = withContextError c $ \cPtr ->
  h2c sym $ \symPtr ->
  marshalArrayLen syms $ \ n symsPtr ->
  marshalArray sorts $ \ sortsPtr ->
  alloca $ \ outConstrPtr ->
  allocaArray n $ \ outProjsPtr -> do
    srtPtr <- checkError cPtr $ z3_mk_tuple_sort cPtr symPtr
                                  (fromIntegral n) symsPtr sortsPtr
                                  outConstrPtr outProjsPtr
    outConstr <- peek outConstrPtr
    outProjs  <- peekArray n outProjsPtr
    tupleSort <- c2h c srtPtr
    tupleCons <- c2h c outConstr
    tupleProjs <- mapM (c2h c) outProjs
    return (tupleSort, tupleCons, tupleProjs)
  where (syms, sorts) = unzip symSorts

-- | Like 'mkTupleSort' but wraps the result in a 'TupleType' record
mkTupleType :: Context -> Symbol -> [(String, Sort)] -> IO TupleType
mkTupleType ctx sym fs = do fs' <- flip zip (map snd fs) <$> mapM (mkStringSymbol ctx . fst) fs
                            (tupleSort, tupleCons, tupleProjs) <- mkTupleSort ctx sym fs'
                            let namedTupleProjs = zip (map fst fs) tupleProjs
                            return $ TupleType {tupleSort, tupleCons, namedTupleProjs}

-- | Create an instance of the tuple sort wrapped in 'TupleType'
mkTuple :: Context -> TupleType -> [AST] -> IO AST
mkTuple ctx TupleType{tupleCons} args = mkApp ctx tupleCons args

-- | Project the i-th field of the given tuple,
mkIndexTuple :: Context -> TupleType -> Int -> AST -> IO AST
mkIndexTuple ctx tt i tup
  | 0 <= i && i < length (tupleProjs tt) = mkApp ctx (tupleProjs tt !! i) [tup]
  | otherwise                            = error "Invalid tuple index used."

-- | Project a field of the given tuple by name,
mkProjTuple :: Context -> TupleType -> String -> AST -> IO AST
mkProjTuple ctx TupleType{namedTupleProjs} f tup = case lookup f namedTupleProjs of
  Just proj -> mkApp ctx proj [tup]
  Nothing   -> error "Invalid tuple field used."

-- | Create a enumeration sort.
--
-- An enumeration sort with n elements. This function will also declare the functions corresponding to the enumerations:
--
-- * @enum_consts@: constants corresponding to the enumerated elements.
-- * @enum_testers@: predicates testing if terms of the enumeration sort correspond to an enumeration.
--
mkEnumerationSort :: Context                           -- ^ logical context
                  -> Symbol                            -- ^ name of the enumeration sort
                  -> [Symbol]                          -- ^ names of the enumerated elements
                  -> IO (Sort, [FuncDecl], [FuncDecl]) -- ^ the created enumeration sort, @enum_consts@, @enum_testers@
mkEnumerationSort ctx sortName constNames = let hn = length constNames in
  allocaArray hn $ \constDeclsPtr ->
    allocaArray hn $ \testDeclsPtr ->
      do s <- marshal z3_mk_enumeration_sort ctx $ \f ->
                marshalArrayLen constNames $ \n constNamesPtr ->
                  h2c sortName $ \sortNamePtr ->
                    f sortNamePtr n constNamesPtr constDeclsPtr testDeclsPtr
         constDecls <- peekArrayToHs ctx hn constDeclsPtr
         testDecls <- peekArrayToHs ctx hn testDeclsPtr
         return (s, constDecls, testDecls)

-- | Create a list sort.
--
-- A list sort over elem_sort. This function declares the corresponding constructors and testers for lists:
--
-- * @nilDecl@: declaration for the empty list
-- * @isnilDecl@:	test for the empty list
-- * @consDecl@:	declaration for a cons cell
-- * @isconsDecl@:	cons cell test
-- * @headDecl@:	list head
-- * @tailDecl@:	list tail
mkListSort :: Context       -- ^ Context
           -> Symbol        -- ^ name of the list sort
           -> Sort          -- ^ sort of list elements
           -> IO (Sort, FuncDecl, FuncDecl, FuncDecl, FuncDecl, FuncDecl, FuncDecl) -- ^ the created list sort, @nilDecl@
                                                                                    -- @isnilDecl@, @consDecl@, @isconsDecl@
                                                                                    -- @headDecl@, @tailDecl@
mkListSort ctx sortName elemSort =
  alloca $ \nilDeclPtr ->
  alloca $ \isNilDeclPtr ->
  alloca $ \consDeclPtr ->
  alloca $ \isConsDeclPtr ->
  alloca $ \headDeclPtr ->
  alloca $ \tailDeclPtr ->
  h2c sortName $ \sortNamePtr ->
    h2c elemSort $ \elemSortPtr ->
      do listSort <- marshal z3_mk_list_sort ctx $ \f ->
           f sortNamePtr elemSortPtr nilDeclPtr isNilDeclPtr consDeclPtr isConsDeclPtr headDeclPtr tailDeclPtr
         nilDecl <- c2h ctx =<< peek nilDeclPtr
         isNilDecl <- c2h ctx =<< peek isNilDeclPtr
         consDecl <- c2h ctx =<< peek consDeclPtr
         isConsDecl <- c2h ctx =<< peek isConsDeclPtr
         headDecl <- c2h ctx =<< peek headDeclPtr
         tailDecl <- c2h ctx =<< peek tailDeclPtr
         return (listSort, nilDecl, isNilDecl, consDecl, isConsDecl, headDecl, tailDecl)

-- | Create a contructor
mkConstructor :: Context                      -- ^ Context
              -> Symbol                       -- ^ Name of the constructor
              -> Symbol                       -- ^ Name of recognizer function
              -> [(Symbol, Maybe Sort, Int)]  -- ^ Name, sort option, and sortRefs
              -> IO Constructor
mkConstructor c sym recog symSortsRefs =
  withContextError c $ \cPtr ->
  h2c sym $ \symPtr ->
  h2c recog $ \recogPtr ->
  marshalArrayLen syms $ \ n symsPtr ->
  marshalArray maybeSorts $ \ sortsPtr ->
  marshalArray (map toInteger refs) $ \ refsPtr -> do
    constructor <- checkError cPtr $ z3_mk_constructor
                       cPtr symPtr recogPtr n symsPtr sortsPtr refsPtr
    c2h c constructor
  where (syms, maybeSorts, refs) = unzip3 symSortsRefs

-- | Create datatype, such as lists, trees, records,
-- enumerations or unions of records.
--
-- The datatype may be recursive.
-- Returns the datatype sort.
mkDatatype :: Context
           -> Symbol
           -> [Constructor]
           -> IO Sort
mkDatatype c sym consList = marshalArrayLen consList $ \ n consPtrs -> do
  toHsCheckError c $ \cPtr -> z3_mk_datatype cPtr (unSymbol sym) n consPtrs

-- | Create list of constructors
mkConstructorList :: Context                      -- ^ Context
                  -> [Constructor]                -- ^ List of Constructors
                  -> IO ConstructorList
mkConstructorList c consList = marshalArrayLen consList $ \ n consPtrs -> do
  toHsCheckError c $ \cPtr -> z3_mk_constructor_list cPtr n consPtrs

-- | Create mutually recursive datatypes, such as a tree and forest.
--
-- Returns the datatype sorts
mkDatatypes :: Context
            -> [Symbol]
            -> [[Constructor]]
            -> IO ([Sort])
mkDatatypes c syms consLists =
  if length consLists == n then do
    consLists' <- mapM (mkConstructorList c) consLists

    withContextError c $ \cPtr ->
      marshalArrayLen syms $ \ symLen symsPtr ->
        marshalArray consLists' $ \ consPtr ->
          allocaArray n $ \ sortsPtr -> do
            z3_mk_datatypes cPtr symLen symsPtr sortsPtr consPtr
            peekArrayToHs c n sortsPtr
    else
      error "Z3.Base.mkDatatypes: lists of different length"
  where n = length syms

-- | Create an set type with a given domain type
mkSetSort :: Context -> Sort -> IO Sort
mkSetSort = liftFun1 z3_mk_set_sort

---------------------------------------------------------------------
-- * Constants and Applications

-- | Declare a constant or function.
mkFuncDecl :: Context   -- ^ Logical context.
            -> Symbol   -- ^ Name of the function (or constant).
            -> [Sort]   -- ^ Function domain (empty for constants).
            -> Sort     -- ^ Return sort of the function.
            -> IO FuncDecl
mkFuncDecl ctx smb dom rng =
  marshal z3_mk_func_decl ctx $ \f ->
    h2c smb $ \ptrSym ->
    marshalArrayLen dom $ \domNum domArr ->
    h2c rng $ \ptrRange ->
      f ptrSym domNum domArr ptrRange

-- | Create a constant or function application.
mkApp :: Context -> FuncDecl -> [AST] -> IO AST
mkApp ctx fd args = marshal z3_mk_app ctx $ \f ->
  h2c fd $ \fdPtr ->
  marshalArrayLen args $ \argsNum argsArr ->
    f fdPtr argsNum argsArr

-- | Declare and create a constant.
--
-- This is a shorthand for:
-- @do xd <- mkFunDecl c x [] s; mkApp c xd []@
mkConst :: Context -> Symbol -> Sort -> IO AST
mkConst = liftFun2 z3_mk_const

-- | Declare a fresh constant or function.
mkFreshFuncDecl :: Context -> String -> [Sort] -> Sort -> IO FuncDecl
mkFreshFuncDecl ctx str dom rng =
  withCString str $ \cstr ->
    marshal z3_mk_fresh_func_decl ctx $ \f ->
    marshalArrayLen dom $ \domNum domArr ->
    h2c rng $ \ptrRange ->
      f cstr domNum domArr ptrRange

-- | Declare and create a fresh constant.
mkFreshConst :: Context -- ^ Logical context.
             -> String  -- ^ Prefix.
             -> Sort    -- ^ Sort of the constant.
             -> IO AST
mkFreshConst = liftFun2 z3_mk_fresh_const

-- | Declare a recursive function.
mkRecFuncDecl :: Context   -- ^ Logical context.
            -> Symbol   -- ^ Name of the function (or constant).
            -> [Sort]   -- ^ Function domain (empty for constants).
            -> Sort     -- ^ Return sort of the function.
            -> IO FuncDecl
mkRecFuncDecl ctx smb dom rng =
  marshal z3_mk_rec_func_decl ctx $ \f ->
    h2c smb $ \ptrSym ->
    marshalArrayLen dom $ \domNum domArr ->
    h2c rng $ \ptrRange ->
      f ptrSym domNum domArr ptrRange

-- | Define the body of a recursive function.
-- Declare it first with mkRecFuncDecl
addRecDef :: Context -- ^ Logical context.
          -> FuncDecl -- ^ Declaration of the function being defined.
          -> [AST] -- ^ Constants to use as the function's formal arguments.
          -> AST   -- ^ Body of the function to define
          -> IO ()
addRecDef ctx decl args body =
  marshal z3_add_rec_def ctx $ \f ->
    h2c decl $ \declPtr ->
    marshalArrayLen args $ \argsNum argsArr ->
    h2c body $ \bodyPtr ->
      f declPtr argsNum argsArr bodyPtr

-------------------------------------------------
-- ** Helpers

-- | Declare and create a variable (aka /constant/).
--
-- An alias for 'mkConst'.
mkVar :: Context -> Symbol -> Sort -> IO AST
mkVar = mkConst

-- | Declarate and create a variable of sort /bool/.
--
-- See 'mkVar'.
mkBoolVar :: Context -> Symbol -> IO AST
mkBoolVar ctx sym = mkVar ctx sym =<< mkBoolSort ctx

-- | Declarate and create a variable of sort /real/.
--
-- See 'mkVar'.
mkRealVar :: Context -> Symbol -> IO AST
mkRealVar ctx sym = mkVar ctx sym =<< mkRealSort ctx

-- | Declarate and create a variable of sort /int/.
--
-- See 'mkVar'.
mkIntVar :: Context -> Symbol -> IO AST
mkIntVar ctx sym = mkVar ctx sym =<< mkIntSort ctx

-- | Declarate and create a variable of sort /bit-vector/.
--
-- See 'mkVar'.
mkBvVar :: Context -> Symbol
                   -> Int     -- ^ bit-width
                   -> IO AST
mkBvVar ctx sym sz = mkVar ctx sym =<< mkBvSort ctx sz

-- | Declare and create a /fresh/ variable (aka /constant/).
--
-- An alias for 'mkFreshConst'.
mkFreshVar :: Context -> String -> Sort -> IO AST
mkFreshVar = mkFreshConst

-- | Declarate and create a /fresh/ variable of sort /bool/.
--
-- See 'mkFreshVar'.
mkFreshBoolVar :: Context -> String -> IO AST
mkFreshBoolVar ctx str = mkFreshVar ctx str =<< mkBoolSort ctx

-- | Declarate and create a /fresh/ variable of sort /real/.
--
-- See 'mkFreshVar'.
mkFreshRealVar :: Context -> String -> IO AST
mkFreshRealVar ctx str = mkFreshVar ctx str =<< mkRealSort ctx

-- | Declarate and create a /fresh/ variable of sort /int/.
--
-- See 'mkFreshVar'.
mkFreshIntVar :: Context -> String -> IO AST
mkFreshIntVar ctx str = mkFreshVar ctx str =<< mkIntSort ctx

-- | Declarate and create a /fresh/ variable of sort /bit-vector/.
--
-- See 'mkFreshVar'.
mkFreshBvVar :: Context -> String
                        -> Int     -- ^ bit-width
                        -> IO AST
mkFreshBvVar ctx str sz = mkFreshVar ctx str =<< mkBvSort ctx sz

---------------------------------------------------------------------
-- Propositional Logic and Equality

-- | Create an AST node representing /true/.
mkTrue :: Context -> IO AST
mkTrue = liftFun0 z3_mk_true

-- | Create an AST node representing /false/.
mkFalse :: Context -> IO AST
mkFalse = liftFun0 z3_mk_false

-- | Create an AST node representing /l = r/.
mkEq :: Context -> AST -> AST -> IO AST
mkEq = liftFun2 z3_mk_eq

-- | The distinct construct is used for declaring the arguments pairwise
-- distinct.
--
-- That is, @and [ args!!i /= args!!j | i <- [0..length(args)-1], j <- [i+1..length(args)-1] ]@
--
-- Requires a non-empty list.
mkDistinct :: Context -> [AST] -> IO AST
mkDistinct =
  liftAstN_err "Z3.Base.mkDistinct: empty list of expressions" z3_mk_distinct

-- | Same as 'mkDistinct' but type-safe.
mkDistinct1 :: Context -> NonEmpty AST -> IO AST
mkDistinct1 = liftAstN1 z3_mk_distinct

-- | Create an AST node representing /not(a)/.
mkNot :: Context -> AST -> IO AST
mkNot = liftFun1 z3_mk_not

-- | Create an AST node representing an if-then-else: /ite(t1, t2, t3)/.
mkIte :: Context -> AST -> AST -> AST -> IO AST
mkIte = liftFun3 z3_mk_ite

-- | Create an AST node representing /t1 iff t2/.
mkIff :: Context -> AST -> AST -> IO AST
mkIff = liftFun2 z3_mk_iff

-- | Create an AST node representing /t1 implies t2/.
mkImplies :: Context -> AST -> AST -> IO AST
mkImplies = liftFun2 z3_mk_implies

-- | Create an AST node representing /t1 xor t2/.
mkXor :: Context -> AST -> AST -> IO AST
mkXor = liftFun2 z3_mk_xor

-- | Create an AST node representing args[0] and ... and args[num_args-1].
mkAnd :: Context -> [AST] -> IO AST
mkAnd = liftAstN z3_mk_true z3_mk_and

-- | Create an AST node representing args[0] or ... or args[num_args-1].
mkOr :: Context -> [AST] -> IO AST
mkOr = liftAstN z3_mk_false z3_mk_or

-------------------------------------------------
-- ** Helpers

-- | Create an AST node representing the given boolean.
mkBool :: Context -> Bool -> IO AST
mkBool ctx False = mkFalse ctx
mkBool ctx True  = mkTrue  ctx

---------------------------------------------------------------------
-- Arithmetic: Integers and Reals

-- | Create an AST node representing args[0] + ... + args[num_args-1].
mkAdd :: Context -> [AST] -> IO AST
mkAdd ctx = maybe (mkInteger ctx 0) (liftAstN1 z3_mk_add ctx) . nonEmpty

-- | Create an AST node representing args[0] * ... * args[num_args-1].
mkMul :: Context -> [AST] -> IO AST
mkMul ctx = maybe (mkInteger ctx 1) (liftAstN1 z3_mk_mul ctx) . nonEmpty

-- | Create an AST node representing args[0] - ... - args[num_args - 1].
--
-- Requires a non-empty list.
mkSub :: Context -> [AST] -> IO AST
mkSub = liftAstN_err "Z3.Base.mkSub: empty list of expressions" z3_mk_sub

-- | Same as 'mkSub' but type-safe.
mkSub1 :: Context -> NonEmpty AST -> IO AST
mkSub1 = liftAstN1 z3_mk_sub

-- | Create an AST node representing -arg.
mkUnaryMinus :: Context -> AST -> IO AST
mkUnaryMinus = liftFun1 z3_mk_unary_minus

-- | Create an AST node representing arg1 div arg2.
mkDiv :: Context -> AST -> AST -> IO AST
mkDiv = liftFun2 z3_mk_div

-- | Create an AST node representing arg1 mod arg2.
mkMod :: Context -> AST -> AST -> IO AST
mkMod = liftFun2 z3_mk_mod

-- | Create an AST node representing arg1 rem arg2.
mkRem :: Context -> AST -> AST -> IO AST
mkRem = liftFun2 z3_mk_rem

-- | Create an AST node representing arg1 ^ arg2.
mkPower :: Context -> AST -> AST -> IO AST
mkPower = liftFun2 z3_mk_power

-- | Create less than.
mkLt :: Context -> AST -> AST -> IO AST
mkLt = liftFun2 z3_mk_lt

-- | Create less than or equal to.
mkLe :: Context -> AST -> AST -> IO AST
mkLe = liftFun2 z3_mk_le

-- | Create greater than.
mkGt :: Context -> AST -> AST -> IO AST
mkGt = liftFun2 z3_mk_gt

-- | Create greater than or equal to.
mkGe :: Context -> AST -> AST -> IO AST
mkGe = liftFun2 z3_mk_ge

-- | Coerce an integer to a real.
mkInt2Real :: Context -> AST -> IO AST
mkInt2Real = liftFun1 z3_mk_int2real

-- | Coerce a real to an integer.
mkReal2Int :: Context -> AST -> IO AST
mkReal2Int = liftFun1 z3_mk_real2int

-- | Check if a real number is an integer.
mkIsInt :: Context -> AST -> IO AST
mkIsInt = liftFun1 z3_mk_is_int

---------------------------------------------------------------------
-- Bit-vectors

-- | Bitwise negation.
mkBvnot :: Context -> AST -> IO AST
mkBvnot = liftFun1 z3_mk_bvnot

-- | Take conjunction of bits in vector, return vector of length 1.
mkBvredand :: Context -> AST -> IO AST
mkBvredand = liftFun1 z3_mk_bvredand

-- | Take disjunction of bits in vector, return vector of length 1.
mkBvredor :: Context -> AST -> IO AST
mkBvredor = liftFun1 z3_mk_bvredor

-- | Bitwise and.
mkBvand :: Context -> AST -> AST -> IO AST
mkBvand = liftFun2 z3_mk_bvand

-- | Bitwise or.
mkBvor :: Context -> AST -> AST -> IO AST
mkBvor = liftFun2 z3_mk_bvor

-- | Bitwise exclusive-or.
mkBvxor :: Context -> AST -> AST -> IO AST
mkBvxor = liftFun2 z3_mk_bvxor

-- | Bitwise nand.
mkBvnand :: Context -> AST -> AST -> IO AST
mkBvnand = liftFun2 z3_mk_bvnand

-- | Bitwise nor.
mkBvnor :: Context -> AST -> AST -> IO AST
mkBvnor = liftFun2 z3_mk_bvnor

-- | Bitwise xnor.
mkBvxnor :: Context -> AST -> AST -> IO AST
mkBvxnor = liftFun2 z3_mk_bvxnor

-- | Standard two's complement unary minus.
mkBvneg :: Context -> AST -> IO AST
mkBvneg = liftFun1 z3_mk_bvneg

-- | Standard two's complement addition.
mkBvadd :: Context -> AST -> AST -> IO AST
mkBvadd = liftFun2 z3_mk_bvadd

-- | Standard two's complement subtraction.
mkBvsub :: Context -> AST -> AST -> IO AST
mkBvsub = liftFun2 z3_mk_bvsub

-- | Standard two's complement multiplication.
mkBvmul :: Context -> AST -> AST -> IO AST
mkBvmul = liftFun2 z3_mk_bvmul

-- | Unsigned division.
mkBvudiv :: Context -> AST -> AST -> IO AST
mkBvudiv = liftFun2 z3_mk_bvudiv

-- | Two's complement signed division.
mkBvsdiv :: Context -> AST -> AST -> IO AST
mkBvsdiv = liftFun2 z3_mk_bvsdiv

-- | Unsigned remainder.
mkBvurem :: Context -> AST -> AST -> IO AST
mkBvurem = liftFun2 z3_mk_bvurem

-- | Two's complement signed remainder (sign follows dividend).
mkBvsrem :: Context -> AST -> AST -> IO AST
mkBvsrem = liftFun2 z3_mk_bvsrem

-- | Two's complement signed remainder (sign follows divisor).
mkBvsmod :: Context -> AST -> AST -> IO AST
mkBvsmod = liftFun2 z3_mk_bvsmod

-- | Unsigned less than.
mkBvult :: Context -> AST -> AST -> IO AST
mkBvult = liftFun2 z3_mk_bvult

-- | Two's complement signed less than.
mkBvslt :: Context -> AST -> AST -> IO AST
mkBvslt = liftFun2 z3_mk_bvslt

-- | Unsigned less than or equal to.
mkBvule :: Context -> AST -> AST -> IO AST
mkBvule = liftFun2 z3_mk_bvule

-- | Two's complement signed less than or equal to.
mkBvsle :: Context -> AST -> AST -> IO AST
mkBvsle = liftFun2 z3_mk_bvsle

-- | Unsigned greater than or equal to.
mkBvuge :: Context -> AST -> AST -> IO AST
mkBvuge = liftFun2 z3_mk_bvuge

-- | Two's complement signed greater than or equal to.
mkBvsge :: Context -> AST -> AST -> IO AST
mkBvsge = liftFun2 z3_mk_bvsge

-- | Unsigned greater than.
mkBvugt :: Context -> AST -> AST -> IO AST
mkBvugt = liftFun2 z3_mk_bvugt

-- | Two's complement signed greater than.
mkBvsgt :: Context -> AST -> AST -> IO AST
mkBvsgt = liftFun2 z3_mk_bvsgt

-- | Concatenate the given bit-vectors.
mkConcat :: Context -> AST -> AST -> IO AST
mkConcat = liftFun2 z3_mk_concat

-- | Extract the bits high down to low from a bitvector of size m to yield a new
-- bitvector of size /n/, where /n = high - low + 1/.
mkExtract :: Context -> Int -> Int -> AST -> IO AST
mkExtract = liftFun3 z3_mk_extract

-- | Sign-extend of the given bit-vector to the (signed) equivalent bitvector
-- of size /m+i/, where /m/ is the size of the given bit-vector.
mkSignExt :: Context -> Int -> AST -> IO AST
mkSignExt = liftFun2 z3_mk_sign_ext

-- | Extend the given bit-vector with zeros to the (unsigned) equivalent
-- bitvector of size /m+i/, where /m/ is the size of the given bit-vector.
mkZeroExt :: Context -> Int -> AST -> IO AST
mkZeroExt = liftFun2 z3_mk_zero_ext

-- | Repeat the given bit-vector up length /i/.
mkRepeat :: Context -> Int -> AST -> IO AST
mkRepeat = liftFun2 z3_mk_repeat

-- | Shift left.
mkBvshl :: Context -> AST -> AST -> IO AST
mkBvshl = liftFun2 z3_mk_bvshl

-- | Logical shift right.
mkBvlshr :: Context -> AST -> AST -> IO AST
mkBvlshr = liftFun2 z3_mk_bvlshr

-- | Arithmetic shift right.
mkBvashr :: Context -> AST -> AST -> IO AST
mkBvashr = liftFun2 z3_mk_bvashr

-- | Rotate bits of /t1/ to the left /i/ times.
mkRotateLeft :: Context -> Int -> AST -> IO AST
mkRotateLeft = liftFun2 z3_mk_rotate_left

-- | Rotate bits of /t1/ to the right /i/ times.
mkRotateRight :: Context -> Int -> AST -> IO AST
mkRotateRight = liftFun2 z3_mk_rotate_right

-- | Rotate bits of /t1/ to the left /t2/ times.
mkExtRotateLeft :: Context -> AST -> AST -> IO AST
mkExtRotateLeft = liftFun2 z3_mk_ext_rotate_left

-- | Rotate bits of /t1/ to the right /t2/ times.
mkExtRotateRight :: Context -> AST -> AST -> IO AST
mkExtRotateRight = liftFun2 z3_mk_ext_rotate_right

-- | Create an /n/ bit bit-vector from the integer argument /t1/.
mkInt2bv :: Context -> Int -> AST -> IO AST
mkInt2bv = liftFun2 z3_mk_int2bv

-- | Create an integer from the bit-vector argument /t1/.
--
-- If /is_signed/ is false, then the bit-vector /t1/ is treated as unsigned.
-- So the result is non-negative and in the range [0..2^/N/-1],
-- where /N/ are the number of bits in /t1/.
-- If /is_signed/ is true, /t1/ is treated as a signed bit-vector.
mkBv2int :: Context -> AST -> Bool -> IO AST
mkBv2int = liftFun2 z3_mk_bv2int

-- | Create a predicate that checks that the bit-wise addition of /t1/ and /t2/
-- does not overflow.
mkBvaddNoOverflow :: Context -> AST -> AST -> Bool -> IO AST
mkBvaddNoOverflow = liftFun3 z3_mk_bvadd_no_overflow

-- | Create a predicate that checks that the bit-wise signed addition of /t1/
-- and /t2/ does not underflow.
mkBvaddNoUnderflow :: Context -> AST -> AST -> IO AST
mkBvaddNoUnderflow = liftFun2 z3_mk_bvadd_no_underflow

-- | Create a predicate that checks that the bit-wise signed subtraction of /t1/
-- and /t2/ does not overflow.
mkBvsubNoOverflow :: Context -> AST -> AST -> IO AST
mkBvsubNoOverflow = liftFun2 z3_mk_bvsub_no_overflow

-- | Create a predicate that checks that the bit-wise subtraction of /t1/ and
-- /t2/ does not underflow.
mkBvsubNoUnderflow :: Context -> AST -> AST -> IO AST
mkBvsubNoUnderflow = liftFun2 z3_mk_bvsub_no_underflow

-- | Create a predicate that checks that the bit-wise signed division of /t1/
-- and /t2/ does not overflow.
mkBvsdivNoOverflow :: Context -> AST -> AST -> IO AST
mkBvsdivNoOverflow = liftFun2 z3_mk_bvsdiv_no_overflow

-- | Check that bit-wise negation does not overflow when /t1/ is interpreted as
-- a signed bit-vector.
mkBvnegNoOverflow :: Context -> AST -> IO AST
mkBvnegNoOverflow = liftFun1 z3_mk_bvneg_no_overflow

-- | Create a predicate that checks that the bit-wise multiplication of /t1/ and
-- /t2/ does not overflow.
mkBvmulNoOverflow :: Context -> AST -> AST -> Bool -> IO AST
mkBvmulNoOverflow = liftFun3 z3_mk_bvmul_no_overflow

-- | Create a predicate that checks that the bit-wise signed multiplication of
-- /t1/ and /t2/ does not underflow.
mkBvmulNoUnderflow :: Context -> AST -> AST -> IO AST
mkBvmulNoUnderflow = liftFun2 z3_mk_bvmul_no_underflow

---------------------------------------------------------------------
-- Arrays

-- | Array read. The argument a is the array and i is the index of the array
-- that gets read.
mkSelect :: Context
            -> AST      -- ^ Array.
            -> AST      -- ^ Index of the array to read.
            -> IO AST
mkSelect = liftFun2 z3_mk_select

-- | Array update.
--
-- The result of this function is an array that is equal to the input array
-- (with respect to select) on all indices except for i, where it maps to v.
--
-- The semantics of this function is given by the theory of arrays described
-- in the SMT-LIB standard. See <http://smtlib.org> for more details.
mkStore :: Context
          -> AST      -- ^ Array.
          -> AST      -- ^ Index /i/ of the array.
          -> AST      -- ^ New value for /i/.
          -> IO AST
mkStore = liftFun3 z3_mk_store

-- | Create the constant array.
--
-- The resulting term is an array, such that a select on an arbitrary index
-- produces the value /v/.
mkConstArray :: Context
            -> Sort   -- ^ Domain sort of the array.
            -> AST    -- ^ Value /v/ that the array maps to.
            -> IO AST
mkConstArray = liftFun2 z3_mk_const_array

-- | Map a function /f/ on the the argument arrays.
--
-- The /n/ nodes args must be of array sorts [domain -> range_i].
-- The function declaration /f/ must have type range_1 .. range_n -> range.
-- The sort of the result is [domain -> range].
mkMap :: Context
        -> FuncDecl   -- ^ Function /f/.
        -> [AST]      -- ^ List of arrays.
        -> IO AST
mkMap ctx fun args = marshal z3_mk_map ctx $ \f ->
  h2c fun $ \funPtr ->
  marshalArrayLen args $ \argsNum argsArr ->
    f funPtr argsNum argsArr

-- | Access the array default value.
--
-- Produces the default range value, for arrays that can be represented as
-- finite maps with a default range value.
mkArrayDefault :: Context
                -> AST      -- ^ Array.
                -> IO AST
mkArrayDefault = liftFun1 z3_mk_array_default

---------------------------------------------------------------------
-- Sets

-- | Create the empty set.
mkEmptySet :: Context
            -> Sort   -- ^ Domain sort of the set.
            -> IO AST
mkEmptySet = liftFun1 z3_mk_empty_set

-- | Create the full set.
mkFullSet :: Context
            -> Sort   -- ^ Domain sort of the set.
            -> IO AST
mkFullSet = liftFun1 z3_mk_full_set

-- | Add an element to a set.
mkSetAdd :: Context
          -> AST      -- ^ Set.
          -> AST      -- ^ Element.
          -> IO AST
mkSetAdd = liftFun2 z3_mk_set_add

-- | Remove an element from a set.
mkSetDel :: Context
          -> AST      -- ^ Set.
          -> AST      -- ^ Element.
          -> IO AST
mkSetDel = liftFun2 z3_mk_set_del

-- | Take the union of a list of sets.
mkSetUnion :: Context -> [AST] -> IO AST
mkSetUnion ctx args = marshal z3_mk_set_union ctx $ \f ->
  marshalArrayLen args $ \argsNum argsArr ->
    f argsNum argsArr

-- | Take the intersection of a list of sets.
mkSetIntersect :: Context -> [AST] -> IO AST
mkSetIntersect ctx args = marshal z3_mk_set_intersect ctx $ \f ->
  marshalArrayLen args $ \argsNum argsArr ->
    f argsNum argsArr

-- | Take the set difference between two sets.
mkSetDifference :: Context
          -> AST      -- ^ First set.
          -> AST      -- ^ Second set.
          -> IO AST
mkSetDifference = liftFun2 z3_mk_set_difference

-- | Take the complement of a set.
mkSetComplement :: Context
          -> AST      -- ^ Set.
          -> IO AST
mkSetComplement = liftFun1 z3_mk_set_complement

-- | Check for set membership.
mkSetMember :: Context
          -> AST      -- ^ Element.
          -> AST      -- ^ Set.
          -> IO AST
mkSetMember = liftFun2 z3_mk_set_member

-- | Check if the first set is a subset of the second set.
mkSetSubset :: Context
          -> AST      -- ^ First set.
          -> AST      -- ^ Second set.
          -> IO AST
mkSetSubset = liftFun2 z3_mk_set_subset

---------------------------------------------------------------------
-- * Numerals

-- | Create a numeral of a given sort.
mkNumeral :: Context -> String -> Sort -> IO AST
mkNumeral = liftFun2 z3_mk_numeral

-- | Create a real from a fraction.
mkReal :: Context -> Int   -- ^ numerator
                  -> Int   -- ^ denominator (/= 0)
                  -> IO AST
mkReal ctx num den
  | den /= 0  = liftFun2 z3_mk_real ctx num den
  | otherwise = error "Z3.Base.mkReal: zero denominator"

-- | Create a numeral of an int, bit-vector, or finite-domain sort.
--
-- This function can be use to create numerals that fit in a
-- /machine integer/.
-- It is slightly faster than 'mkNumeral' since it is not necessary
-- to parse a string.
mkInt :: Context -> Int -> Sort -> IO AST
mkInt = liftFun2 z3_mk_int

-- | Create a numeral of an int, bit-vector, or finite-domain sort.
--
-- This function can be use to create numerals that fit in a
-- /machine unsigned integer/.
-- It is slightly faster than 'mkNumeral' since it is not necessary
-- to parse a string.
mkUnsignedInt :: Context -> Word -> Sort -> IO AST
mkUnsignedInt = liftFun2 z3_mk_unsigned_int

-- | Create a numeral of an int, bit-vector, or finite-domain sort.
--
-- This function can be use to create numerals that fit in a
-- /machine 64-bit integer/.
-- It is slightly faster than 'mkNumeral' since it is not necessary
-- to parse a string.
mkInt64 :: Context -> Int64 -> Sort -> IO AST
mkInt64 = liftFun2 z3_mk_int64

-- | Create a numeral of an int, bit-vector, or finite-domain sort.
--
-- This function can be use to create numerals that fit in a
-- /machine unsigned 64-bit integer/.
-- It is slightly faster than 'mkNumeral' since it is not necessary
-- to parse a string.
mkUnsignedInt64 :: Context -> Word64 -> Sort -> IO AST
mkUnsignedInt64 = liftFun2 z3_mk_unsigned_int64

-------------------------------------------------
-- ** Helpers

-- | Create a numeral of an int, bit-vector, or finite-domain sort.
mkIntegral :: Integral a => Context -> a -> Sort -> IO AST
mkIntegral c n s = mkNumeral c n_str s
  where n_str = show $ toInteger n

-- | Create a numeral of sort /real/ from a 'Rational'.
mkRational :: Context -> Rational -> IO AST
mkRational = mkRealNum

-- | Create a numeral of sort /real/ from a 'Fixed'.
mkFixed :: HasResolution a => Context -> Fixed a -> IO AST
mkFixed ctx = mkRational ctx . toRational

-- | Create a numeral of sort /real/ from a 'Real'.
mkRealNum :: Real r => Context -> r -> IO AST
mkRealNum c n = mkNumeral c n_str =<< mkRealSort c
  where r     = toRational n
        r_n   = toInteger $ numerator r
        r_d   = toInteger $ denominator r
        n_str = show r_n ++ " / " ++ show r_d

-- | Create a numeral of sort /int/ from an 'Integer'.
mkInteger :: Context -> Integer -> IO AST
mkInteger = mkIntNum

-- | Create a numeral of sort /int/ from an 'Integral'.
mkIntNum :: Integral a => Context -> a -> IO AST
mkIntNum ctx n = mkIntegral ctx n =<< mkIntSort ctx

-- | Create a numeral of sort /Bit-vector/ from an 'Integer'.
mkBitvector :: Context -> Int      -- ^ bit-width
                       -> Integer  -- ^ integer value
                       -> IO AST
mkBitvector = mkBvNum

-- | Create a numeral of sort /Bit-vector/ from an 'Integral'.
mkBvNum :: Integral i => Context -> Int    -- ^ bit-width
                                 -> i      -- ^ integer value
                                 -> IO AST
mkBvNum ctx s n = mkIntegral ctx n =<< mkBvSort ctx s

---------------------------------------------------------------------
-- Sequences and regular expressions

-- | Create a sequence sort out of the sort for the elements.
mkSeqSort :: Context -> Sort -> IO Sort
mkSeqSort = liftFun1 z3_mk_seq_sort

-- | Check if s is a sequence sort.
isSeqSort :: Context -> Sort -> IO Bool
isSeqSort = liftFun1 z3_is_seq_sort

-- | Create a regular expression sort out of a sequence sort.
mkReSort :: Context -> Sort -> IO Sort
mkReSort = liftFun1 z3_mk_re_sort

-- | Check if s is a regular expression sort.
isReSort :: Context -> Sort -> IO Bool
isReSort = liftFun1 z3_is_re_sort

-- | Create a sort for 8 bit strings. This function creates a sort for ASCII
-- strings. Each character is 8 bits.
mkStringSort :: Context -> IO Sort
mkStringSort = liftFun0 z3_mk_string_sort

-- | Check if s is a string sort.
isStringSort :: Context -> Sort -> IO Bool
isStringSort = liftFun1 z3_is_string_sort

-- | Create a string constant out of the string that is passed in.
mkString :: Context -> String -> IO AST
mkString = liftFun1 z3_mk_string

-- | Determine if s is a string constant.
isString :: Context -> AST -> IO Bool
isString = liftFun1 z3_is_string

-- | Retrieve the string constant stored in s.
getString :: Context -> AST -> IO String
getString = liftFun1 z3_get_string

-- | Create an empty sequence of the sequence sort seq.
mkSeqEmpty :: Context -> Sort -> IO AST
mkSeqEmpty = liftFun1 z3_mk_seq_empty

-- | Create a unit sequence of a.
mkSeqUnit :: Context -> AST -> IO AST
mkSeqUnit = liftFun1 z3_mk_seq_unit

-- | Concatenate sequences.
mkSeqConcat :: Context -> [AST] -> IO AST
mkSeqConcat c as
  | null as = error "Z3.Base.mkSeqConcet: empty list of expressions"
  | otherwise         = marshal z3_mk_seq_concat c $ marshalArrayLen as

-- | Check if prefix is a prefix of s.
mkSeqPrefix :: Context
            -> AST -- ^ prefix
            -> AST -- ^ s
            -> IO AST
mkSeqPrefix = liftFun2 z3_mk_seq_prefix

-- | Check if suffix is a suffix of s.
mkSeqSuffix :: Context
            -> AST -- ^ suffix
            -> AST -- ^ s
            -> IO AST
mkSeqSuffix = liftFun2 z3_mk_seq_suffix

-- | Check if container contains containee.
mkSeqContains :: Context
              -> AST -- ^ container
              -> AST -- ^ containee
              -> IO AST
mkSeqContains = liftFun2 z3_mk_seq_contains

-- | Check if s1 is equal or lexicographically strictly less than s2.
mkStrLt :: Context
        -> AST -- ^ s1
        -> AST -- ^ s2
        -> IO AST
mkStrLt = liftFun2 z3_mk_str_lt

-- | Check if s1 is lexicographically strictly less than s2.
mkStrLe :: Context
        -> AST -- ^ s1
        -> AST -- ^ s2
        -> IO AST
mkStrLe = liftFun2 z3_mk_str_le

-- | Extract subsequence starting at offset of length.
mkSeqExtract :: Context
             -> AST -- ^ s
             -> AST -- ^ offset
             -> AST -- ^ length
             -> IO AST
mkSeqExtract = liftFun3 z3_mk_seq_extract

-- | Replace the first occurrence of src with dst in s.
mkSeqReplace :: Context
             -> AST -- ^ s
             -> AST -- ^ src
             -> AST -- ^ dst
             -> IO AST
mkSeqReplace = liftFun3 z3_mk_seq_replace

-- | Retrieve from s the unit sequence positioned at position index.
mkSeqAt :: Context
        -> AST -- ^ s
        -> AST -- ^ index
        -> IO AST
mkSeqAt = liftFun2 z3_mk_seq_at

-- | Retrieve from s the element positioned at position index.
mkSeqNth :: Context
        -> AST -- ^ s
        -> AST -- ^ index
        -> IO AST
mkSeqNth = liftFun2 z3_mk_seq_nth

-- | Return the length of the sequence s.
mkSeqLength :: Context
            -> AST -- ^ s
            -> IO AST
mkSeqLength = liftFun1 z3_mk_seq_length

-- | Return index of first occurrence of substr in s starting from offset
-- offset. If s does not contain substr, then the value is -1, if offset is the
-- length of s, then the value is -1 as well. The function is under-specified if
-- offset is negative or larger than the length of s.
mkSeqIndex :: Context
           -> AST -- ^ s
           -> AST -- ^ substr
           -> AST -- ^ offset
           -> IO AST
mkSeqIndex = liftFun3 z3_mk_seq_index

-- | Convert string to integer.
mkStrToInt :: Context -> AST -> IO AST
mkStrToInt = liftFun1 z3_mk_str_to_int

-- | Integer to string conversion.
mkIntToStr :: Context -> AST -> IO AST
mkIntToStr = liftFun1 z3_mk_int_to_str

-- | Create a regular expression that accepts the sequence.
mkSeqToRe :: Context -> AST -> IO AST
mkSeqToRe = liftFun1 z3_mk_seq_to_re

-- | Check if seq is in the language generated by the regular expression re.
mkSeqInRe :: Context
          -> AST -- ^ seq
          -> AST -- ^ re
          -> IO AST
mkSeqInRe = liftFun2 z3_mk_seq_in_re

-- | Create the regular language re+.
mkRePlus :: Context -> AST -> IO AST
mkRePlus = liftFun1 z3_mk_re_plus

-- | Create the regular language re*.
mkReStar :: Context -> AST -> IO AST
mkReStar = liftFun1 z3_mk_re_star

-- | Create the regular language [re].
mkReOption :: Context -> AST -> IO AST
mkReOption = liftFun1 z3_mk_re_option

-- | Create the union of the regular languages.
mkReUnion :: (Integral int) => Context -> int -> [AST] -> IO AST
mkReUnion c i as
  | i <  0            = error "Z3.Base.mkReUnion: negative size"
  | i >= 0 && null as = error "Z3.Base.mkReUnion: empty list of expressions"
  | otherwise         = marshal z3_mk_re_union c $ marshalArrayLen as

-- | Create the concatenation of the regular languages.
mkReConcat :: (Integral int) => Context -> int -> [AST] -> IO AST
mkReConcat c i as
  | i <  0            = error "Z3.Base.mkReConcat: negative size"
  | i >= 0 && null as = error "Z3.Base.mkReConcat: empty list of expressions"
  | otherwise         = marshal z3_mk_re_concat c $ marshalArrayLen as

-- | Create the range regular expression over two sequences of length 1.
mkReRange :: Context
          -> AST -- ^ lo
          -> AST -- ^ hi
          -> IO AST
mkReRange = liftFun2 z3_mk_re_range

-- | Create a regular expression loop. The supplied regular expression r is
-- repeated between lo and hi times. The lo should be below hi with one
-- exception: when supplying the value hi as 0, the meaning is to repeat the
-- argument r at least lo number of times, and with an unbounded upper bound.
mkReLoop :: (Integral int)
         => Context
         -> AST -- ^ r
         -> int -- ^ lo
         -> int -- ^ hi
         -> IO AST
mkReLoop c a i j
  | i < 0     = error "Z3.Base.mkReLoop: negative size"
  | i < 0     = error "Z3.Base.mkReLoop: empty list of expressions"
  | otherwise = liftFun3 z3_mk_re_loop c a i j

-- | Create the intersection of the regular languages.
mkReIntersect :: (Integral int) => Context -> int -> [AST] -> IO AST
mkReIntersect c i as
  | i <  0            = error "Z3.Base.mkReIntersect: negative size"
  | i >= 0 && null as = error "Z3.Base.mkReIntersect: empty list of expressions"
  | otherwise         = marshal z3_mk_re_intersect c $ marshalArrayLen as

-- | Create the complement of the regular language.
mkReComplement :: Context -> AST -> IO AST
mkReComplement = liftFun1 z3_mk_re_complement

-- | Create an empty regular expression of sort re.
mkReEmpty :: Context -> Sort -> IO AST
mkReEmpty = liftFun1 z3_mk_re_empty

-- | Create an universal regular expression of sort re.
mkReFull :: Context -> Sort -> IO AST
mkReFull = liftFun1 z3_mk_re_full

 ---------------------------------------------------------------------
-- Quantifiers

-- | Create a pattern for quantifier instantiation.
--
-- Z3 uses pattern matching to instantiate quantifiers.
-- If a pattern is not provided for a quantifier, then Z3 will automatically
-- compute a set of patterns for it. However, for optimal performance,
-- the user should provide the patterns.
--
-- Patterns comprise a list of terms.
-- The list should be non-empty.
-- If the list comprises of more than one term, it is a called a multi-pattern.
--
-- In general, one can pass in a list of (multi-)patterns in the quantifier
-- constructor.
mkPattern :: Context
              -> [AST]        -- ^ Terms.
              -> IO Pattern
mkPattern _ [] = error "Z3.Base.mkPattern: empty list of expressions"
mkPattern c es = marshal z3_mk_pattern c $ marshalArrayLen es

-- | Create a bound variable.
--
-- Bound variables are indexed by de-Bruijn indices.
--
-- See <http://z3prover.github.io/api/html/group__capi.html#ga1d4da8849fca699b345322f8ee1fa31e>
mkBound :: Context
            -> Int    -- ^ de-Bruijn index.
            -> Sort
            -> IO AST
mkBound c i s
  | i >= 0    = liftFun2 z3_mk_bound c i s
  | otherwise = error "Z3.Base.mkBound: negative de-Bruijn index"

type MkZ3Quantifier = Ptr Z3_context -> CUInt
                      -> CUInt -> Ptr (Ptr Z3_pattern)
                      -> CUInt -> Ptr (Ptr Z3_sort) -> Ptr (Ptr Z3_symbol)
                      -> Ptr Z3_ast
                      -> IO (Ptr Z3_ast)

marshalMkQ :: MkZ3Quantifier
          -> Context
          -> Int
          -> [Pattern]
          -> [Symbol]
          -> [Sort]
          -> AST
          -> IO AST
marshalMkQ z3_mk_Q ctx weight pats x s body = marshal z3_mk_Q ctx $ \f ->
  marshalArrayLen pats $ \n patsArr ->
  marshalArray x $ \xArr ->
  marshalArray s $ \sArr ->
  h2c weight $ \weightC ->
  h2c body $ \bodyPtr ->
    f weightC n patsArr len sArr xArr bodyPtr
  where len
          | l == 0        = error "Z3.Base.mkQuantifier:\
              \ quantifier with 0 bound variables"
          | l /= length x = error "Z3.Base.mkQuantifier:\
              \ different number of symbols and sorts"
          | otherwise     = fromIntegral l
          where l = length s
-- | 'mkForall' with weight 0 (the default).
mkForall :: Context
          -> [Pattern]  -- ^ Instantiation patterns (see 'mkPattern').
          -> [Symbol]   -- ^ Bound (quantified) variables /xs/.
          -> [Sort]     -- ^ Sorts of the bound variables.
          -> AST        -- ^ Body of the quantifier.
          -> IO AST
mkForall = flip mkForallW 0

-- | Create a forall formula.
--
-- The bound variables are de-Bruijn indices created using 'mkBound'.
--
-- Z3 applies the convention that the last element in /xs/ refers to the
-- variable with index 0, the second to last element of /xs/ refers to the
-- variable with index 1, etc.
mkForallW :: Context
          -> Int        -- ^ quantifiers are associated with weights indicating the importance of using the quantifier during instantiation. By default, pass the weight 0.
          -> [Pattern]  -- ^ Instantiation patterns (see 'mkPattern').
          -> [Symbol]   -- ^ Bound (quantified) variables /xs/.
          -> [Sort]     -- ^ Sorts of the bound variables.
          -> AST        -- ^ Body of the quantifier.
          -> IO AST
mkForallW = marshalMkQ z3_mk_forall


-- | Create an exists formula.
--
-- Similar to 'mkForallW'.
mkExistsW :: Context -> Int -> [Pattern] -> [Symbol] -> [Sort] -> AST -> IO AST
mkExistsW = marshalMkQ z3_mk_exists

-- | `mkExistsW` with weight 0 (the default).
mkExists :: Context -> [Pattern] -> [Symbol] -> [Sort] -> AST -> IO AST
mkExists = flip mkExistsW 0

-- TODO: Z3_mk_quantifier
-- TODO: Z3_mk_quantifier_ex

type MkZ3QuantifierConst = Ptr Z3_context
                           -> CUInt
                           -> CUInt
                           -> Ptr (Ptr Z3_app)
                           -> CUInt
                           -> Ptr (Ptr Z3_pattern)
                           -> Ptr Z3_ast
                           -> IO (Ptr Z3_ast)

marshalMkQConst :: MkZ3QuantifierConst
                  -> Context
                  -> Int
                  -> [Pattern]
                  -> [App]
                  -> AST
                -> IO AST
marshalMkQConst z3_mk_Q_const ctx weight pats apps body =
  marshal z3_mk_Q_const ctx $ \f ->
    marshalArrayLen pats $ \patsNum patsArr ->
    marshalArray    apps $ \appsArr ->
    h2c weight $ \weightC ->
    h2c body $ \bodyPtr ->
      f weightC len appsArr patsNum patsArr bodyPtr
  where len
          | l == 0        = error "Z3.Base.mkQuantifierConst:\
              \ quantifier with 0 bound variables"
          | otherwise     = fromIntegral l
          where l = length apps

-- | Create a universal quantifier using a list of constants that will form the
-- set of bound variables.
mkForallWConst :: Context
              -> Int       -- ^ quantifiers are associated with weights indicating the importance of using the quantifier during instantiation. By default, pass the weight 0.

              -> [Pattern] -- ^ Instantiation patterns (see 'mkPattern').
              -> [App]     -- ^ Constants to be abstracted into bound variables.
              -> AST       -- ^ Quantifier body.
              -> IO AST
mkForallWConst = marshalMkQConst z3_mk_forall_const


-- | 'mkForallWConst' with weight set to 0 (the default).
mkForallConst :: Context -> [Pattern] -> [App] -> AST -> IO AST
mkForallConst = flip mkForallWConst 0

-- | Create a existential quantifier using a list of constants that will form
-- the set of bound variables.
mkExistsWConst :: Context
              -> Int       -- ^ quantifiers are associated with weights indicating the importance of using the quantifier during instantiation. By default, pass the weight 0.
              -> [Pattern] -- ^ Instantiation patterns (see 'mkPattern').
              -> [App]     -- ^ Constants to be abstracted into bound variables.
              -> AST       -- ^ Quantifier body.
              -> IO AST
mkExistsWConst = marshalMkQConst z3_mk_exists_const

-- | 'mkForallWConst' with weight set to 0 (the default).
mkExistsConst :: Context -> [Pattern] -> [App] -> AST -> IO AST
mkExistsConst = flip mkExistsWConst 0

-- TODO: Z3_mk_quantifier_const
-- TODO: Z3_mk_quantifier_const_ex

---------------------------------------------------------------------
-- Accessors

-- TODO: Z3_get_symbol_kind

-- TODO: Z3_get_symbol_int

-- | Return the symbol name.
getSymbolString :: Context -> Symbol -> IO String
getSymbolString = liftFun1 z3_get_symbol_string

-- | Return the sort name as a symbol.
getSortName :: Context -> Sort -> IO Symbol
getSortName = liftFun1 z3_get_sort_name

-- | Convert a Z3_sort into Z3_ast. This is just type casting.
sortToAst :: Context -> Sort -> IO AST
sortToAst = liftFun1 z3_sort_to_ast

-- | Return a unique identifier for s.
getSortId :: Context -> Sort -> IO Int
getSortId = liftFun1 z3_get_sort_id

-- | Compare sorts.
isEqSort :: Context -> Sort -> Sort -> IO Bool
isEqSort = liftFun2 z3_is_eq_sort

-- | Return the sort kind of the given sort.
getSortKind :: Context -> Sort -> IO SortKind
getSortKind ctx sort = toSortKind <$> liftFun1 z3_get_sort_kind ctx sort
  where toSortKind :: Z3_sort_kind -> SortKind
        toSortKind k
          | k == z3_uninterpreted_sort      = Z3_UNINTERPRETED_SORT
          | k == z3_bool_sort               = Z3_BOOL_SORT
          | k == z3_int_sort                = Z3_INT_SORT
          | k == z3_real_sort               = Z3_REAL_SORT
          | k == z3_bv_sort                 = Z3_BV_SORT
          | k == z3_array_sort              = Z3_ARRAY_SORT
          | k == z3_datatype_sort           = Z3_DATATYPE_SORT
          | k == z3_relation_sort           = Z3_RELATION_SORT
          | k == z3_finite_domain_sort      = Z3_FINITE_DOMAIN_SORT
          | k == z3_floating_point_sort     = Z3_FLOATING_POINT_SORT
          | k == z3_rounding_mode_sort      = Z3_ROUNDING_MODE_SORT
          | k == z3_unknown_sort            = Z3_UNKNOWN_SORT
          | otherwise                 =
              error "Z3.Base.getSortKind: unknown `Z3_sort_kind'"

-- | Return the size of the given bit-vector sort.
getBvSortSize :: Context -> Sort -> IO Int
getBvSortSize = liftFun1 z3_get_bv_sort_size

getFiniteDomainSortSize :: Context -> Sort -> IO (Maybe Word64)
getFiniteDomainSortSize ctx sort = alloca $ \sizePtr ->
  withContext ctx $ \ctxPtr ->
    h2c sort $ \sortPtr ->
      do success <- z3_get_finite_domain_sort_size ctxPtr sortPtr sizePtr
         returnValueToMaybe success $ (fromIntegral <$> peek sizePtr)


-- TODO: Z3_get_array_sort_size

getArraySortDomain :: Context -> Sort -> IO Sort
getArraySortDomain = liftFun1 z3_get_array_sort_domain

getArraySortRange :: Context -> Sort -> IO Sort
getArraySortRange = liftFun1 z3_get_array_sort_range

getTupleSortMkDecl :: Context -> Sort -> IO FuncDecl
getTupleSortMkDecl = liftFun1 z3_get_tuple_sort_mk_decl

getTupleSortNumFields :: Context -> Sort -> IO Int
getTupleSortNumFields = liftFun1 z3_get_tuple_sort_num_fields

getTupleSortFieldDecl :: Context -> Sort -> Int -> IO FuncDecl
getTupleSortFieldDecl = liftFun2 z3_get_tuple_sort_field_decl

-- | Get list of constructors for datatype.
getDatatypeSortConstructors :: Context
                            -> Sort           -- ^ Datatype sort.
                            -> IO [FuncDecl]  -- ^ Constructor declarations.
getDatatypeSortConstructors c dtSort =
  withContextError c $ \cPtr ->
  h2c dtSort $ \dtSortPtr -> do
    numCons <- checkError cPtr $ z3_get_datatype_sort_num_constructors cPtr dtSortPtr
    T.mapM (getConstructor dtSortPtr) [0..(numCons-1)]
  where
    getConstructor dtSortPtr idx =
      toHsCheckError c $ \cPtr -> z3_get_datatype_sort_constructor cPtr dtSortPtr idx

-- | Get list of recognizers for datatype.
getDatatypeSortRecognizers :: Context
                           -> Sort           -- ^ Datatype sort.
                           -> IO [FuncDecl]  -- ^ Constructor recognizers.
getDatatypeSortRecognizers c dtSort =
  withContextError c $ \cPtr ->
  h2c dtSort $ \dtSortPtr -> do
    numCons <- checkError cPtr $ z3_get_datatype_sort_num_constructors cPtr dtSortPtr
    T.mapM (getRecognizer dtSortPtr) [0..(numCons-1)]
  where
    getRecognizer dtSortPtr idx =
      toHsCheckError c $ \cPtr -> z3_get_datatype_sort_recognizer cPtr dtSortPtr idx

-- | Get list of accessors for the datatype constructor.
getDatatypeSortConstructorAccessors :: Context
                                    -> Sort             -- ^ Datatype sort.
                                    -> IO [[FuncDecl]]  -- ^ Constructor accessors.
getDatatypeSortConstructorAccessors c dtSort =
  withContextError c $ \cPtr ->
  h2c dtSort $ \dtSortPtr -> do
    numCons <- checkError cPtr $ z3_get_datatype_sort_num_constructors cPtr dtSortPtr
    T.mapM (getAccessors dtSortPtr) [0..(numCons-1)]
  where
    getConstructor dtSortPtr idx_c =
      withContext c $ \cPtr -> z3_get_datatype_sort_constructor cPtr dtSortPtr idx_c

    getAccessors dtSortPtr idx_c = do
      consPtr <- getConstructor dtSortPtr idx_c
      numAs <- toHsCheckError c $ \cPtr -> z3_get_arity cPtr consPtr
      if numAs > 0  -- NB: (0::CUInt) - 1 == 0
        then T.mapM (\idx_a -> getAccessors' dtSortPtr idx_c idx_a) [0..(numAs - 1)]
        else return []

    getAccessors' dtSortPtr idx_c idx_a =
      toHsCheckError c $ \cPtr -> z3_get_datatype_sort_constructor_accessor cPtr dtSortPtr idx_c idx_a

-- TODO: Z3_get_relation_arity

-- TODO: Z3_get_relation_column

mkAtMost :: Context -> [AST] -> Int -> IO AST
mkAtMost _ctx [] _n = error "Z3.Base.mkAtMost: empty list of expressions"
mkAtMost  ctx es  n =
  marshal z3_mk_atmost ctx $ \f ->
  marshalArrayLen es $ \esLen esArr ->
  h2c n $ \n' ->
  f esLen esArr n'

mkAtLeast :: Context -> [AST] -> Int -> IO AST
mkAtLeast _ctx [] _n = error "Z3.Base.mkAtLeast: empty list of expressions"
mkAtLeast  ctx es  n =
  marshal z3_mk_atleast ctx $ \f ->
  marshalArrayLen es $ \esLen esArr ->
  h2c n $ \n' ->
  f esLen esArr n'

-- TODO: Z3_mk_pble

-- TODO: Z3_mk_pbge

-- TODO: Z3_mk_pbeq

-- TODO: Z3_func_decl_to_ast

-- TODO: Z3_is_eq_func_decl

-- TODO: Z3_get_func_decl_id

-- | Return the constant declaration name as a symbol.
getDeclName :: Context -> FuncDecl -> IO Symbol
getDeclName c decl = h2c decl $ \declPtr ->
  Symbol <$> withContextError c (\cPtr -> z3_get_decl_name cPtr declPtr)

-- TODO: Z3_get_decl_kind

-- TODO: Z3_get_domain_size

-- | Returns the number of parameters of the given declaration
getArity :: Context -> FuncDecl -> IO Int
getArity = liftFun1 z3_get_arity

-- | Returns the sort of the i-th parameter of the given function declaration
getDomain :: Context
             -> FuncDecl         -- ^ A function declaration
             -> Int              -- ^ i
             -> IO Sort
getDomain = liftFun2 z3_get_domain

-- | Returns the range of the given declaration.
getRange :: Context -> FuncDecl -> IO Sort
getRange = liftFun1 z3_get_range

getDeclNumParameters :: Context -> FuncDecl -> IO Int
getDeclNumParameters = liftFun1 z3_get_decl_num_parameters

-- TODO: Z3_get_decl_parameter_kind

-- TODO: Z3_get_decl_int_parameter

-- TODO: Z3_get_decl_double_parameter

-- TODO: Z3_get_decl_symbol_parameter

-- TODO: Z3_get_decl_sort_parameter

-- TODO: Z3_get_decl_ast_parameter

-- TODO: Z3_get_decl_func_decl_parameter

-- TODO: Z3_get_decl_rational_parameter

-- | Convert an app into AST. This is just type casting.
appToAst :: Context -> App -> IO AST
appToAst = liftFun1 z3_app_to_ast

-- | Return the declaration of a constant or function application.
getAppDecl :: Context -> App -> IO FuncDecl
getAppDecl = liftFun1 z3_get_app_decl

-- | Return the number of argument of an application. If t is an constant, then the number of arguments is 0.
getAppNumArgs :: Context -> App -> IO Int
getAppNumArgs = liftFun1 z3_get_app_num_args

-- | Return the i-th argument of the given application.
getAppArg :: Context -> App -> Int -> IO AST
getAppArg = liftFun2 z3_get_app_arg

-- | Return a list of all the arguments of the given application.
getAppArgs :: Context -> App -> IO [AST]
getAppArgs ctx a = do
  n <- getAppNumArgs ctx a
  T.forM [0..n-1] (getAppArg ctx a)

-- TODO: Z3_is_eq_ast

-- TODO: Z3_get_ast_id

-- TODO: Z3_get_ast_hash

-- | Return the sort of an AST node.
getSort :: Context -> AST -> IO Sort
getSort = liftFun1 z3_get_sort

isWellSorted :: Context -> AST -> IO Bool
isWellSorted = liftFun1 z3_is_well_sorted

-- TODO: fix doc
-- | Return Z3_L_TRUE if a is true, Z3_L_FALSE if it is false, and Z3_L_UNDEF
-- otherwise.
getBoolValue :: Context -> AST -> IO (Maybe Bool)
getBoolValue c a = h2c a $ \astPtr ->
  castLBool <$> withContextError c (\cPtr -> z3_get_bool_value cPtr astPtr)
  where castLBool :: Z3_lbool -> Maybe Bool
        castLBool lb
          | lb == z3_l_true  = Just True
          | lb == z3_l_false = Just False
          | lb == z3_l_undef = Nothing
          | otherwise        =
              error "Z3.Base.castLBool: illegal `Z3_lbool' value"

-- | Return the kind of the given AST.
getAstKind :: Context -> AST -> IO ASTKind
getAstKind ctx ast = toAstKind <$> liftFun1 z3_get_ast_kind ctx ast
  where toAstKind :: Z3_ast_kind -> ASTKind
        toAstKind k
          | k == z3_numeral_ast       = Z3_NUMERAL_AST
          | k == z3_app_ast           = Z3_APP_AST
          | k == z3_var_ast           = Z3_VAR_AST
          | k == z3_quantifier_ast    = Z3_QUANTIFIER_AST
          | k == z3_sort_ast          = Z3_SORT_AST
          | k == z3_func_decl_ast     = Z3_FUNC_DECL_AST
          | k == z3_unknown_ast       = Z3_UNKNOWN_AST
          | otherwise                 =
              error "Z3.Base.getAstKind: unknown `Z3_ast_kind'"

-- | Return True if an ast is APP_AST, False otherwise.
isApp :: Context -> AST -> IO Bool
isApp = liftFun1 z3_is_app

-- TODO: Z3_is_numeral_ast

-- TODO: Z3_is_algebraic_number

-- | Convert an ast into an APP_AST. This is just type casting.
toApp :: Context -> AST -> IO App
toApp = liftFun1 z3_to_app

-- TODO: Z3_to_func_decl

-- | Return numeral value, as a string of a numeric constant term.
getNumeralString :: Context -> AST -> IO String
getNumeralString = liftFun1 z3_get_numeral_string

-- TODO: Z3_get_numeral_decimal_string

-- | Return the numerator (as a numeral AST) of a numeral AST of sort Real.
--
-- Reference: <https://z3prover.github.io/api/html/group__capi.html#ga2d37084eb47ea0ab19638a3407ce610b>
getNumerator :: Context -> AST -> IO AST
getNumerator = liftFun1 z3_get_numerator

-- | Return the denominator (as a numeral AST) of a numeral AST of sort Real.
--
-- Reference: <https://z3prover.github.io/api/html/group__capi.html#ga07549939888e8fdfc8e0fde1776c31a7>
getDenominator :: Context -> AST -> IO AST
getDenominator = liftFun1 z3_get_denominator

-- TODO: Z3_get_numeral_small

-- TODO: Z3_get_numeral_int

-- TODO: Z3_get_numeral_int

-- TODO: Z3_get_numeral_uint

-- TODO: Z3_get_numeral_uint64

-- TODO: Z3_get_numeral_int64

-- TODO: Z3_get_numeral_rational_int64

-- TODO: Z3_get_algebraic_number_lower

-- TODO: Z3_get_algebraic_number_upper

-- TODO: Z3_pattern_to_ast

-- TODO: Z3_get_pattern_num_terms

-- TODO: Z3_get_pattern

getIndexValue :: Context -> AST -> IO Int
getIndexValue = liftFun1 z3_get_index_value

isQuantifierForall :: Context -> AST -> IO Bool
isQuantifierForall = liftFun1 z3_is_quantifier_forall

isQuantifierExists :: Context -> AST -> IO Bool
isQuantifierExists ctx = fmap not . isQuantifierForall ctx

getQuantifierWeight :: Context -> AST -> IO Int
getQuantifierWeight = liftFun1 z3_get_quantifier_weight

getQuantifierNumPatterns :: Context -> AST -> IO Int
getQuantifierNumPatterns = liftFun1 z3_get_quantifier_num_patterns

getQuantifierPatternAST :: Context -> AST -> Int -> IO AST
getQuantifierPatternAST = liftFun2 z3_get_quantifier_pattern_ast

getQuantifierPatterns :: Context -> AST -> IO [AST]
getQuantifierPatterns ctx a = do
  n <- getQuantifierNumPatterns ctx a
  T.forM [0..n-1] (getQuantifierPatternAST ctx a)

getQuantifierNumNoPatterns :: Context -> AST -> IO Int
getQuantifierNumNoPatterns = liftFun1 z3_get_quantifier_num_no_patterns

getQuantifierNoPatternAST :: Context -> AST -> Int -> IO AST
getQuantifierNoPatternAST = liftFun2 z3_get_quantifier_no_pattern_ast

getQuantifierNoPatterns :: Context -> AST -> IO [AST]
getQuantifierNoPatterns ctx a = do
  n <- getQuantifierNumNoPatterns ctx a
  T.forM [0..n-1] (getQuantifierNoPatternAST ctx a)

getQuantifierNumBound :: Context -> AST -> IO Int
getQuantifierNumBound = liftFun1 z3_get_quantifier_num_bound

getQuantifierBoundName :: Context -> AST -> Int -> IO Symbol
getQuantifierBoundName = liftFun2 z3_get_quantifier_bound_name

getQuantifierBoundSort :: Context -> AST -> Int -> IO Sort
getQuantifierBoundSort = liftFun2 z3_get_quantifier_bound_sort

getQuantifierBoundVars :: Context -> AST -> IO [AST]
getQuantifierBoundVars ctx a = do
  n <- getQuantifierNumBound ctx a
  T.forM [0..n-1] $ \i -> do
    b <- getQuantifierBoundName ctx a i
    s <- getQuantifierBoundSort ctx a i
    mkVar ctx b s

getQuantifierBody :: Context -> AST -> IO AST
getQuantifierBody = liftFun1 z3_get_quantifier_body

simplify :: Context -> AST -> IO AST
simplify = liftFun1 z3_simplify

simplifyEx :: Context -> AST -> Params -> IO AST
simplifyEx = liftFun2 z3_simplify_ex

-- TODO: Z3_simplify_get_help

-- TODO: Z3_simplify_get_param_descrs

-------------------------------------------------
-- ** Helpers

-- | Read a 'Bool' value from an 'AST'
getBool :: Context -> AST -> IO Bool
getBool c a = fromJust <$> getBoolValue c a
  -- TODO: throw an custom error if Nothing?
  -- TODO: Refactor castLBool?

-- | Read an 'Integer' value from an 'AST'
getInt :: Context -> AST -> IO Integer
getInt c a = read <$> getNumeralString c a

-- | Read a 'Rational' value from an 'AST'
getReal :: Context -> AST -> IO Rational
getReal c a = parse <$> getNumeralString c a
  where parse :: String -> Rational
        parse s
          | [(i, sj)] <- reads s = i % parseDen (dropWhile (== ' ') sj)
          | otherwise            = error "Z3.Base.getReal: no parse"

        parseDen :: String -> Integer
        parseDen ""       = 1
        parseDen ('/':sj) = read sj
        parseDen _        = error "Z3.Base.getReal: no parse"

---------------------------------------------------------------------
-- Modifiers

-- TODO Z3_update_term

substituteVars :: Context -> AST -> [AST] -> IO AST
substituteVars ctx a vars =
  marshal z3_substitute_vars ctx $ \f ->
    h2c a $ \aPtr ->
    marshalArrayLen vars $ \varsNum varsArr ->
      f aPtr varsNum varsArr

substitute :: Context -> AST -> [(AST, AST)] -> IO AST
substitute ctx a substs =
  let froms = map fst substs
      tos   = map snd substs
  in marshal z3_substitute ctx $ \f ->
    h2c a $ \aPtr ->
    marshalArrayLen froms $ \fromsLen fromsArr ->
    marshalArray    tos   $ \         tosArr   ->
      f aPtr fromsLen fromsArr tosArr

-- TODO Z3_translate

---------------------------------------------------------------------
-- Models

-- | Evaluate an AST node in the given model.
--
-- The evaluation may fail for the following reasons:
--
--     * /t/ contains a quantifier.
--     * the model /m/ is partial.
--     * /t/ is type incorrect.
modelEval :: Context
            -> Model  -- ^ Model /m/.
            -> AST    -- ^ Expression to evaluate /t/.
            -> Bool   -- ^ Model completion?
            -> IO (Maybe AST)
modelEval ctx m a b =
  withContext ctx $ \ctxPtr ->
  alloca $ \aptr2 ->
    h2c a $ \astPtr ->
    h2c m $ \mPtr ->
    h2c b $ \b' ->
    checkError ctxPtr
      (z3_model_eval ctxPtr mPtr astPtr b' aptr2) >>= peekAST aptr2
  where peekAST :: Ptr (Ptr Z3_ast) -> Bool -> IO (Maybe AST)
        peekAST _p False = return Nothing
        peekAST  p True  = fmap Just . c2h ctx =<< peek p

getConstInterp :: Context -> Model -> FuncDecl -> IO (Maybe AST)
getConstInterp ctx m fd = marshal z3_model_get_const_interp ctx $ \f ->
  h2c m $ \mPtr ->
  h2c fd $ \fdPtr ->
    f mPtr fdPtr

modelTranslate :: Context -> Model -> Context -> IO Model
modelTranslate = liftFun2 z3_model_translate

hasInterp :: Context -> Model -> FuncDecl -> IO Bool
hasInterp = liftFun2 z3_model_has_interp

numConsts :: Context -> Model -> IO Word
numConsts = liftFun1 z3_model_get_num_consts

numFuncs :: Context -> Model -> IO Word
numFuncs = liftFun1 z3_model_get_num_funcs

getConstDecl :: Context -> Model -> Word -> IO FuncDecl
getConstDecl = liftFun2 z3_model_get_const_decl

getFuncDecl :: Context -> Model -> Word -> IO FuncDecl
getFuncDecl = liftFun2 z3_model_get_func_decl

getConsts :: Context -> Model -> IO [FuncDecl]
getConsts ctx m = do
  n <- numConsts ctx m
  forM [0..n-1] $ \i -> getConstDecl ctx m i

getFuncs :: Context -> Model -> IO [FuncDecl]
getFuncs ctx m = do
  n <- numFuncs ctx m
  forM [0..n-1] $ \i -> getFuncDecl ctx m i

-- | Evaluate an array as a function, if possible.
evalArray :: Context -> Model -> AST -> IO (Maybe FuncModel)
evalArray ctx model array =
    do -- The array must first be evaluated normally, to get it into
       -- 'as-array' form, which is required to acquire the FuncDecl.
       evaldArrayMb <- eval ctx model array
       case evaldArrayMb of
         Nothing -> return Nothing
         Just evaldArray ->
             do canConvert <- isAsArray ctx evaldArray
                if canConvert
                  then
                    do arrayDecl <- getAsArrayFuncDecl ctx evaldArray
                       evalFunc ctx model arrayDecl
                  else return Nothing


-- | Return the function declaration f associated with a (_ as_array f) node.
getAsArrayFuncDecl :: Context -> AST -> IO FuncDecl
getAsArrayFuncDecl = liftFun1 z3_get_as_array_func_decl

-- | The (_ as-array f) AST node is a construct for assigning interpretations
-- for arrays in Z3. It is the array such that forall indices i we have that
-- (select (_ as-array f) i) is equal to (f i). This procedure returns True if
-- the a is an as-array AST node.
isAsArray :: Context -> AST -> IO Bool
isAsArray = liftFun1 z3_is_as_array

isEqAST :: Context -> AST -> AST -> IO Bool
isEqAST = liftFun2 z3_is_eq_ast

addFuncInterp :: Context -> Model -> FuncDecl -> AST -> IO FuncInterp
addFuncInterp = liftFun3 z3_add_func_interp

addConstInterp :: Context -> Model -> FuncDecl -> AST -> IO ()
addConstInterp = liftFun3 z3_add_const_interp


getMapFromInterp :: Context -> FuncInterp -> IO [([AST], AST)]
getMapFromInterp ctx interp =
    do n <- funcInterpGetNumEntries ctx interp
       entries <- mapM (funcInterpGetEntry ctx interp) [0..n-1]
       mapM (getEntry ctx) entries

getEntry :: Context -> FuncEntry -> IO ([AST], AST)
getEntry ctx entry =
    do val <- funcEntryGetValue ctx entry
       args <- getEntryArgs ctx entry
       return (args, val)

getEntryArgs :: Context -> FuncEntry -> IO [AST]
getEntryArgs ctx entry =
    do n <- funcEntryGetNumArgs ctx entry
       mapM (funcEntryGetArg ctx entry) [0..n-1]

-- | Return the interpretation of the function f in the model m.
-- Return NULL, if the model does not assign an interpretation for f.
-- That should be interpreted as: the f does not matter.
getFuncInterp :: Context -> Model -> FuncDecl -> IO (Maybe FuncInterp)
getFuncInterp ctx m fd = marshal z3_model_get_func_interp ctx $ \f ->
  h2c m $ \mPtr ->
  h2c fd $ \fdPtr ->
    f mPtr fdPtr

-- | Return the number of entries in the given function interpretation.
funcInterpGetNumEntries :: Context -> FuncInterp -> IO Int
funcInterpGetNumEntries = liftFun1 z3_func_interp_get_num_entries

-- | Return a _point_ of the given function intepretation.
-- It represents the value of f in a particular point.
funcInterpGetEntry :: Context -> FuncInterp -> Int -> IO FuncEntry
funcInterpGetEntry = liftFun2 z3_func_interp_get_entry

-- | Return the 'else' value of the given function interpretation.
funcInterpGetElse :: Context -> FuncInterp -> IO AST
funcInterpGetElse = liftFun1 z3_func_interp_get_else

-- | Return the arity (number of arguments) of the given function
-- interpretation.
funcInterpGetArity :: Context -> FuncInterp -> IO Int
funcInterpGetArity = liftFun1 z3_func_interp_get_arity

-- | Return the value of this point.
funcEntryGetValue :: Context -> FuncEntry -> IO AST
funcEntryGetValue = liftFun1 z3_func_entry_get_value

-- | Return the number of arguments in a Z3_func_entry object.
funcEntryGetNumArgs :: Context -> FuncEntry -> IO Int
funcEntryGetNumArgs = liftFun1 z3_func_entry_get_num_args

-- | Return an argument of a Z3_func_entry object.
funcEntryGetArg :: Context -> FuncEntry -> Int -> IO AST
funcEntryGetArg = liftFun2 z3_func_entry_get_arg

-- | Convert the given model into a string.
modelToString :: Context -> Model -> IO String
modelToString = liftFun1 z3_model_to_string

-- | Alias for 'modelToString'.
showModel :: Context -> Model -> IO String
showModel = modelToString
{-# DEPRECATED showModel "Use modelToString instead." #-}

-------------------------------------------------
-- ** Helpers

-- | Type of an evaluation function for 'AST'.
--
-- Evaluation may fail (i.e. return 'Nothing') for a few
-- reasons, see 'modelEval'.
type EvalAst a = Model -> AST -> IO (Maybe a)

-- | An alias for 'modelEval' with model completion enabled.
eval :: Context -> EvalAst AST
eval ctx m a = modelEval ctx m a True

-- | Evaluate an AST node of sort /bool/ in the given model.
--
-- See 'modelEval' and 'getBool'.
evalBool :: Context -> EvalAst Bool
evalBool ctx m ast = eval ctx m ast >>= T.traverse (getBool ctx)

-- | Evaluate an AST node of sort /int/ in the given model.
--
-- See 'modelEval' and 'getInt'.
evalInt :: Context -> EvalAst Integer
evalInt ctx m ast = eval ctx m ast >>= T.traverse (getInt ctx)

-- | Evaluate an AST node of sort /real/ in the given model.
--
-- See 'modelEval' and 'getReal'.
evalReal :: Context -> EvalAst Rational
evalReal ctx m ast = eval ctx m ast >>= T.traverse (getReal ctx)

-- | Evaluate an AST node of sort /bit-vector/ in the given model.
--
-- The flag /signed/ decides whether the bit-vector value is
-- interpreted as a signed or unsigned integer.
--
-- See 'modelEval' and 'mkBv2int'.
evalBv :: Context -> Bool -- ^ signed?
                  -> EvalAst Integer
evalBv ctx signed m ast =
  mkBv2int ctx ast signed >>= eval ctx m >>= T.traverse (\a -> getInt ctx a)

-- | Evaluate a /collection/ of AST nodes in the given model.
evalT :: Traversable t => Context -> Model -> t AST -> IO (Maybe (t AST))
evalT c = mapEval (eval c)

-- | Run a evaluation function on a 'Traversable' data structure of 'AST's
-- (e.g. @[AST]@, @Vector AST@, @Maybe AST@, etc).
--
-- This a generic version of 'evalT' which can be used in combination with
-- other helpers. For instance, @mapEval (evalInt c)@ can be used to obtain
-- the 'Integer' interpretation of a list of 'AST' of sort /int/.
mapEval :: Traversable t => EvalAst a -> Model -> t AST -> IO (Maybe (t a))
mapEval f m = fmap T.sequence . T.mapM (f m)

{- TODO: Parameterize FuncModel

data FuncModel a b = FuncModel [([a], b)] b

type FuncModelAST = FuncModel AST AST

evalFuncWith :: Context -> Model -> EvalAst a -> EvalAst b -> FuncDecl -> IO (Maybe (FuncModel a b))

-}

-- | The interpretation of a function.
data FuncModel = FuncModel
    { interpMap :: [([AST], AST)]
      -- ^ Mapping from arguments to values.
    , interpElse :: AST
      -- ^ Default value.
    }

-- | Evaluate a function declaration to a list of argument/value pairs.
evalFunc :: Context -> Model -> FuncDecl -> IO (Maybe FuncModel)
evalFunc ctx m fDecl =
    do interpMb <- getFuncInterp ctx m fDecl
       case interpMb of
         Nothing -> return Nothing
         Just interp ->
             do funcMap  <- getMapFromInterp ctx interp
                elsePart <- funcInterpGetElse ctx interp
                return (Just $ FuncModel funcMap elsePart)

---------------------------------------------------------------------
-- Interaction logging

-- TODO

---------------------------------------------------------------------
-- String Conversion

-- | Pretty-printing mode for converting ASTs to strings.  The mode
-- can be one of the following:
--
-- * Z3_PRINT_SMTLIB_FULL: Print AST nodes in SMTLIB verbose format.
--
-- * Z3_PRINT_LOW_LEVEL: Print AST nodes using a low-level format.
--
-- * Z3_PRINT_SMTLIB_COMPLIANT: Print AST nodes in SMTLIB 1.x
-- compliant format.
--
-- * Z3_PRINT_SMTLIB2_COMPLIANT: Print AST nodes in SMTLIB 2.x
-- compliant format.
data ASTPrintMode
  = Z3_PRINT_SMTLIB_FULL
  | Z3_PRINT_LOW_LEVEL
  | Z3_PRINT_SMTLIB2_COMPLIANT

-- | Set the pretty-printing mode for converting ASTs to strings.
setASTPrintMode :: Context -> ASTPrintMode -> IO ()
setASTPrintMode ctx mode = withContextError ctx $ \ctxPtr ->
  case mode of
       Z3_PRINT_SMTLIB_FULL ->
         z3_set_ast_print_mode ctxPtr z3_print_smtlib_full
       Z3_PRINT_LOW_LEVEL ->
         z3_set_ast_print_mode ctxPtr z3_print_low_level
       Z3_PRINT_SMTLIB2_COMPLIANT ->
         z3_set_ast_print_mode ctxPtr z3_print_smtlib2_compliant

-- | Convert an AST to a string.
astToString :: Context -> AST -> IO String
astToString = liftFun1 z3_ast_to_string

-- | Convert a pattern to a string.
patternToString :: Context -> Pattern -> IO String
patternToString = liftFun1 z3_pattern_to_string

-- | Convert a sort to a string.
sortToString :: Context -> Sort -> IO String
sortToString = liftFun1 z3_sort_to_string

-- | Convert a FuncDecl to a string.
funcDeclToString :: Context -> FuncDecl -> IO String
funcDeclToString = liftFun1 z3_func_decl_to_string

-- | Convert the given benchmark into SMT-LIB formatted string.
--
-- The output format can be configured via 'setASTPrintMode'.
benchmarkToSMTLibString :: Context
                            -> String   -- ^ name
                            -> String   -- ^ logic
                            -> String   -- ^ status
                            -> String   -- ^ attributes
                            -> [AST]    -- ^ assumptions
                            -> AST      -- ^ formula
                            -> IO String
benchmarkToSMTLibString ctx name logic status attr assump form =
  marshal z3_benchmark_to_smtlib_string ctx $ \f ->
    withCString name $ \namePtr ->
    withCString logic $ \logicPtr ->
    withCString status $ \statusPtr ->
    withCString attr $ \attrPtr ->
    marshalArrayLen assump $ \assumpNum assumpArr ->
    h2c form $ \formPtr ->
      f namePtr logicPtr statusPtr attrPtr assumpNum assumpArr formPtr

---------------------------------------------------------------------
-- Tactics

mkTactic :: Context -> String -> IO Tactic
mkTactic = liftFun1 z3_mk_tactic

andThenTactic :: Context -> Tactic -> Tactic -> IO Tactic
andThenTactic = liftFun2 z3_tactic_and_then

orElseTactic :: Context -> Tactic -> Tactic -> IO Tactic
orElseTactic = liftFun2 z3_tactic_or_else

skipTactic :: Context -> IO Tactic
skipTactic = liftFun0 z3_tactic_skip

tryForTactic :: Context -> Tactic -> Int -> IO Tactic
tryForTactic = liftFun2 z3_tactic_try_for

tacticUsingParams :: Context -> Tactic -> Params -> IO Tactic
tacticUsingParams = liftFun2 z3_tactic_using_params

repeatTactic :: Context -> Tactic -> Int -> IO Tactic
repeatTactic = liftFun2 z3_tactic_repeat

mkQuantifierEliminationTactic :: Context -> IO Tactic
mkQuantifierEliminationTactic ctx = mkTactic ctx "qe"

mkAndInverterGraphTactic :: Context -> IO Tactic
mkAndInverterGraphTactic ctx = mkTactic ctx "aig"

applyTactic :: Context -> Tactic -> Goal -> IO ApplyResult
applyTactic = liftFun2 z3_tactic_apply

applyResultToString :: Context -> ApplyResult -> IO String
applyResultToString = liftFun1 z3_apply_result_to_string

getApplyResultNumSubgoals :: Context -> ApplyResult -> IO Int
getApplyResultNumSubgoals = liftFun1 z3_apply_result_get_num_subgoals

getApplyResultSubgoal :: Context -> ApplyResult -> Int -> IO Goal
getApplyResultSubgoal = liftFun2 z3_apply_result_get_subgoal

getApplyResultSubgoals :: Context -> ApplyResult -> IO [Goal]
getApplyResultSubgoals ctx a = do
  n <- getApplyResultNumSubgoals ctx a
  T.forM [0..n-1] (getApplyResultSubgoal ctx a)

mkGoal :: Context -> Bool -> Bool -> Bool -> IO Goal
mkGoal = liftFun3 z3_mk_goal

goalAssert :: Context -> Goal -> AST -> IO ()
goalAssert = liftFun2 z3_goal_assert

getGoalSize :: Context -> Goal -> IO Int
getGoalSize = liftFun1 z3_goal_size

getGoalFormula :: Context -> Goal -> Int -> IO AST
getGoalFormula = liftFun2 z3_goal_formula

getGoalFormulas :: Context -> Goal -> IO [AST]
getGoalFormulas ctx g = do
  n <- getGoalSize ctx g
  T.forM [0..n-1] (getGoalFormula ctx g)

goalToString :: Context -> Goal -> IO String
goalToString = liftFun1 z3_goal_to_string

convertModel :: Context -> Goal -> Model -> IO Model
convertModel = liftFun2 z3_goal_convert_model

---------------------------------------------------------------------
-- Parser interface

parseSMTLib2String :: Context
                   -> String     -- ^ string to parse
                   -> [Symbol]   -- ^ sort names
                   -> [Sort]     -- ^ sorts
                   -> [Symbol]   -- ^ declaration names
                   -> [FuncDecl] -- ^ declarations
                   -> IO [AST]
parseSMTLib2String ctx str sortNames sorts declNames decls =
  marshal z3_parse_smtlib2_string ctx $ \f ->
    withCString str $ \cstr ->
    marshalArrayLen sorts $ \sortNum sortArr ->
    marshalArray sortNames $ \sortNameArr ->
    marshalArrayLen decls $ \declNum declArr ->
    marshalArray declNames $ \declNameArr ->
      f cstr sortNum sortNameArr sortArr declNum declNameArr declArr

parseSMTLib2File :: Context
                 -> String     -- ^ file name
                 -> [Symbol]   -- ^ sort names
                 -> [Sort]     -- ^ sorts
                 -> [Symbol]   -- ^ declaration names
                 -> [FuncDecl] -- ^ declarations
                 -> IO [AST]
parseSMTLib2File ctx file sortNames sorts declNames decls =
  marshal z3_parse_smtlib2_file ctx $ \f ->
    withCString file $ \fileName ->
    marshalArrayLen sorts $ \sortNum sortArr ->
    marshalArray sortNames $ \sortNameArr ->
    marshalArrayLen decls $ \declNum declArr ->
    marshalArray declNames $ \declNameArr ->
      f fileName sortNum sortNameArr sortArr declNum declNameArr declArr

evalSMTLib2String :: Context
                  -> String    -- ^ string to parse
                  -> IO String
evalSMTLib2String ctx cmd =
  marshal z3_eval_smtlib2_string ctx $ \f ->
    withCString cmd $ \command ->
      f command

---------------------------------------------------------------------
-- Error handling

-- | Z3 exceptions.
--
-- Z3 errors are re-thrown as Haskell 'Z3Error' exceptions,
-- see 'Control.Exception'.
data Z3Error = Z3Error
    { errCode :: Z3ErrorCode
    , errMsg  :: String
    }
  deriving Typeable

instance Show Z3Error where
  show (Z3Error _ s) = "Z3 error: " ++ s

-- | Z3 error codes.
data Z3ErrorCode = SortError | IOB | InvalidArg | ParserError | NoParser
  | InvalidPattern | MemoutFail  | FileAccessError | InternalFatal
  | InvalidUsage   | DecRefError | Z3Exception
  deriving (Show, Typeable)

toZ3Error :: Z3_error_code -> Z3ErrorCode
toZ3Error e
  | e == z3_sort_error        = SortError
  | e == z3_iob               = IOB
  | e == z3_invalid_arg       = InvalidArg
  | e == z3_parser_error      = ParserError
  | e == z3_no_parser         = NoParser
  | e == z3_invalid_pattern   = InvalidPattern
  | e == z3_memout_fail       = MemoutFail
  | e == z3_file_access_error = FileAccessError
  | e == z3_internal_fatal    = InternalFatal
  | e == z3_invalid_usage     = InvalidUsage
  | e == z3_dec_ref_error     = DecRefError
  | e == z3_exception         = Z3Exception
  | otherwise                 = error "Z3.Base.toZ3Error: illegal `Z3_error_code' value"

instance Exception Z3Error

-- | Throws a z3 error
z3Error :: Z3ErrorCode -> String -> IO ()
z3Error cd = throw . Z3Error cd

-- | Throw an exception if a Z3 error happened
checkError :: Ptr Z3_context -> IO a -> IO a
checkError cPtr m = do
  m <* (z3_get_error_code cPtr >>= throwZ3Exn)
  where getErrStr i  = peekCString =<< z3_get_error_msg cPtr i
        throwZ3Exn i = when (i /= z3_ok) $ getErrStr i >>= z3Error (toZ3Error i)

---------------------------------------------------------------------
-- Miscellaneous

data Version
  = Version {
      z3Major    :: !Int
    , z3Minor    :: !Int
    , z3Build    :: !Int
    , z3Revision :: !Int
    }
  deriving (Eq,Ord)

instance Show Version where
  show (Version major minor build _) =
    show major ++ "." ++ show minor ++ "." ++ show build

-- | Return Z3 version number information.
getVersion :: IO Version
getVersion =
  alloca $ \ptrMinor ->
  alloca $ \ptrMajor ->
  alloca $ \ptrBuild ->
  alloca $ \ptrRevision -> do
    z3_get_version ptrMinor ptrMajor ptrBuild ptrRevision
    minor    <- fromIntegral <$> peek ptrMinor
    major    <- fromIntegral <$> peek ptrMajor
    build    <- fromIntegral <$> peek ptrBuild
    revision <- fromIntegral <$> peek ptrRevision
    return $ Version minor major build revision

---------------------------------------------------------------------
-- Externalm Theory Plugins

-- TODO

---------------------------------------------------------------------
-- Fixedpoint facilities

newtype Fixedpoint = Fixedpoint { unFixedpoint :: ForeignPtr Z3_fixedpoint }
    deriving Eq

instance Marshal Fixedpoint (Ptr Z3_fixedpoint) where
  c2h = mkC2hRefCount Fixedpoint z3_fixedpoint_inc_ref z3_fixedpoint_dec_ref
  h2c fp = withForeignPtr (unFixedpoint fp)

mkFixedpoint :: Context -> IO Fixedpoint
mkFixedpoint = liftFun0 z3_mk_fixedpoint

fixedpointAddRule :: Context -> Fixedpoint -> AST -> Symbol -> IO ()
fixedpointAddRule = liftFun3 z3_fixedpoint_add_rule

fixedpointSetParams :: Context -> Fixedpoint -> Params -> IO ()
fixedpointSetParams = liftFun2 z3_fixedpoint_set_params

fixedpointRegisterRelation :: Context -> Fixedpoint -> FuncDecl -> IO ()
fixedpointRegisterRelation = liftFun2 z3_fixedpoint_register_relation

fixedpointQueryRelations :: Context -> Fixedpoint -> [FuncDecl] -> IO Result
fixedpointQueryRelations ctx fixedpoint fds =
  marshal z3_fixedpoint_query_relations ctx $ \f ->
    h2c fixedpoint $ \fixedpointPtr ->
    marshalArrayLen fds $ \fdsNum fdsArr ->
      f fixedpointPtr fdsNum fdsArr

fixedpointGetAnswer :: Context -> Fixedpoint -> IO AST
fixedpointGetAnswer = liftFun1 z3_fixedpoint_get_answer

fixedpointGetAssertions :: Context -> Fixedpoint -> IO [AST]
fixedpointGetAssertions = liftFun1 z3_fixedpoint_get_assertions

---------------------------------------------------------------------
-- Floating-Point Arithmetic

-- | Create the RoundingMode sort.
mkFpaRoundingModeSort :: Context -> IO Sort
mkFpaRoundingModeSort = liftFun0 z3_mk_fpa_rounding_mode_sort

-- | Create a numeral of RoundingMode sort which represents the
-- NearestTiesToEven rounding mode.
mkFpaRoundNearestTiesToEven :: Context -> IO AST
mkFpaRoundNearestTiesToEven = liftFun0 z3_mk_fpa_round_nearest_ties_to_even

-- | Create a numeral of RoundingMode sort which represents the
-- NearestTiesToEven rounding mode.
mkFpaRne :: Context -> IO AST
mkFpaRne = liftFun0 z3_mk_fpa_rne

-- | Create a numeral of RoundingMode sort which represents the
-- NearestTiesToAway rounding mode.
mkFpaRoundNearestTiesToAway :: Context -> IO AST
mkFpaRoundNearestTiesToAway = liftFun0 z3_mk_fpa_round_nearest_ties_to_away

-- | Create a numeral of RoundingMode sort which represents the
-- NearestTiesToAway rounding mode.
mkFpaRna :: Context -> IO AST
mkFpaRna = liftFun0 z3_mk_fpa_rna

-- | Create a numeral of RoundingMode sort which represents the
-- TowardPositive rounding mode.
mkFpaRoundTowardPositive :: Context -> IO AST
mkFpaRoundTowardPositive = liftFun0 z3_mk_fpa_round_toward_positive

-- | Create a numeral of RoundingMode sort which represents the
-- TowardPositive rounding mode.
mkFpaRtp :: Context -> IO AST
mkFpaRtp = liftFun0 z3_mk_fpa_rtp

-- | Create a numeral of RoundingMode sort which represents the
-- TowardNegative rounding mode.
mkFpaRoundTowardNegative :: Context -> IO AST
mkFpaRoundTowardNegative = liftFun0 z3_mk_fpa_round_toward_negative

-- | Create a numeral of RoundingMode sort which represents the
-- TowardNegative rounding mode.
mkFpaRtn :: Context -> IO AST
mkFpaRtn = liftFun0 z3_mk_fpa_rtn

-- | Create a numeral of RoundingMode sort which represents the
-- TowardZero rounding mode.
mkFpaRoundTowardZero :: Context -> IO AST
mkFpaRoundTowardZero = liftFun0 z3_mk_fpa_round_toward_zero

-- | Create a numeral of RoundingMode sort which represents the
-- TowardZero rounding mode.
mkFpaRtz :: Context -> IO AST
mkFpaRtz = liftFun0 z3_mk_fpa_rtz

-- | Create a FloatingPoint sort.
mkFpaSort :: Integral int
          => Context -- ^ Context
          -> int -- ^ Number of exponent bits
          -> int -- ^ Number of significand bits
          -> IO Sort
mkFpaSort = liftFun2 z3_mk_fpa_sort

-- | Create the half-precision (16-bit) FloatingPoint sort.
mkFpaSortHalf :: Context -> IO Sort
mkFpaSortHalf = liftFun0 z3_mk_fpa_sort_half

-- | Create the half-precision (16-bit) FloatingPoint sort.
mkFpaSort16 :: Context -> IO Sort
mkFpaSort16 = liftFun0 z3_mk_fpa_sort_16

-- | Create the single-precision (32-bit) FloatingPoint sort.
mkFpaSortSingle :: Context -> IO Sort
mkFpaSortSingle = liftFun0 z3_mk_fpa_sort_single

-- | Create the single-precision (32-bit) FloatingPoint sort.
mkFpaSort32 :: Context -> IO Sort
mkFpaSort32 = liftFun0 z3_mk_fpa_sort_32

-- | Create the double-precision (64-bit) FloatingPoint sort.
mkFpaSortDouble :: Context -> IO Sort
mkFpaSortDouble = liftFun0 z3_mk_fpa_sort_double

-- | Create the double-precision (64-bit) FloatingPoint sort.
mkFpaSort64 :: Context -> IO Sort
mkFpaSort64 = liftFun0 z3_mk_fpa_sort_64

-- | Create the quadruple-precision (128-bit) FloatingPoint sort.
mkFpaSortQuadruple :: Context -> IO Sort
mkFpaSortQuadruple = liftFun0 z3_mk_fpa_sort_quadruple

-- | Create the quadruple-precision (128-bit) FloatingPoint sort.
mkFpaSort128 :: Context -> IO Sort
mkFpaSort128 = liftFun0 z3_mk_fpa_sort_128

-- | Create a floating-point NaN of sort @s@.
mkFpaNaN :: Context -> Sort -> IO AST
mkFpaNaN = liftFun1 z3_mk_fpa_nan

-- | Create a floating-point infinity of sort @s@.
mkFpaInf :: Context -- ^ Context
         -> Sort    -- ^ Target sort
         -> Bool    -- ^ Indicates whether the result should be negative
         -> IO AST
mkFpaInf = liftFun2 z3_mk_fpa_inf

-- | Create a floating-point zero of sort @s@.
mkFpaZero :: Context -- ^ Context
          -> Sort    -- ^ Target sort
          -> Bool    -- ^ Indicates whether the result should be negative
          -> IO AST
mkFpaZero = liftFun2 z3_mk_fpa_zero

-- | Create an expression of FloatingPoint sort from three bit-vector
-- expressions.
--
-- This is the operator named `fp' in the SMT FP theory definition.
-- Note that @sgn@ is required to be a bit-vector of size 1.
-- Significand and exponent are required to be longer than 1 and 2
-- respectively. The FloatingPoint sort of the resulting expression
-- is automatically determined from the bit-vector sizes of the
-- arguments. The exponent is assumed to be in IEEE-754 biased
-- representation.
mkFpaFp :: Context -- ^ Context
        -> AST     -- ^ Sign
        -> AST     -- ^ Exponent
        -> AST     -- ^ Significand
        -> IO AST
mkFpaFp = liftFun3 z3_mk_fpa_fp

-- | Create a numeral of FloatingPoint sort from a float.
mkFpaNumeralFloat :: Context -> Float -> Sort -> IO AST
mkFpaNumeralFloat = liftFun2 z3_mk_fpa_numeral_float

-- | Create a numeral of FloatingPoint sort from a double.
mkFpaNumeralDouble :: Context -> Double -> Sort -> IO AST
mkFpaNumeralDouble = liftFun2 z3_mk_fpa_numeral_double

-- | Create a numeral of FloatingPoint sort from a signed integer.
mkFpaNumeralInt :: Integral int => Context -> int -> Sort -> IO AST
mkFpaNumeralInt = liftFun2 z3_mk_fpa_numeral_int

-- | Create a numeral of FLoatingPoint sort from a sign bit and
-- two integers.
mkFpaNumeralIntUInt :: Integral int
                    => Context -- ^ Context
                    -> Bool    -- ^ Sign bit (true == negative)
                    -> int     -- ^ Significand
                    -> int     -- ^ Exponent
                    -> Sort    -- ^ Result sort
                    -> IO AST
mkFpaNumeralIntUInt = liftFun4 z3_mk_fpa_numeral_int_uint

-- | Create a numeral of FloatingPoint sort from a sign bit and
-- two 64-bit integers.
mkFpaNumeralInt64UInt64 :: Integral int
                        => Context -- ^ Context
                        -> Bool    -- ^ Sign bit (true == negative)
                        -> int     -- ^ Significand
                        -> int     -- ^ Exponent
                        -> Sort    -- ^ Result sort
                        -> IO AST
mkFpaNumeralInt64UInt64 = liftFun4 z3_mk_fpa_numeral_int64_uint64

-- | Floating-point absolute value.
mkFpaAbs :: Context -> AST -> IO AST
mkFpaAbs = liftFun1 z3_mk_fpa_abs

-- | Floating-point negation.
mkFpaNeg :: Context -> AST -> IO AST
mkFpaNeg = liftFun1 z3_mk_fpa_neg

-- | Floating-point addition.
mkFpaAdd :: Context -- ^ Context
         -> AST     -- ^ Rounding Mode
         -> AST     -- ^ FloatingPoint sort term
         -> AST     -- ^ FloatingPoint sort term
         -> IO AST
mkFpaAdd = liftFun3 z3_mk_fpa_add

-- | Floating-point subtraction.
mkFpaSub :: Context -- ^ Context
         -> AST     -- ^ Rounding Mode
         -> AST     -- ^ FloatingPoint sort term
         -> AST     -- ^ FloatingPoint sort term
         -> IO AST
mkFpaSub = liftFun3 z3_mk_fpa_sub

-- | Floating-point multiplication.
mkFpaMul :: Context -- ^ Context
         -> AST     -- ^ Rounding Mode
         -> AST     -- ^ FloatingPoint sort term
         -> AST     -- ^ FloatingPoint sort term
         -> IO AST
mkFpaMul = liftFun3 z3_mk_fpa_mul

-- | Floating-point division.
mkFpaDiv :: Context -- ^ Context
         -> AST     -- ^ Rounding Mode
         -> AST     -- ^ FloatingPoint sort term
         -> AST     -- ^ FloatingPoint sort term
         -> IO AST
mkFpaDiv = liftFun3 z3_mk_fpa_div

-- | Floating-point fused multiply-add.
--
-- The result is @round((t1 * t2) + t3)@.
mkFpaFma :: Context -> AST -> AST -> AST -> AST -> IO AST
mkFpaFma = liftFun4 z3_mk_fpa_fma

-- | Floating-point square root.
mkFpaSqrt :: Context -> AST -> AST -> IO AST
mkFpaSqrt = liftFun2 z3_mk_fpa_sqrt

-- | Floating-point remainder.
mkFpaRem :: Context -> AST -> AST -> IO AST
mkFpaRem = liftFun2 z3_mk_fpa_rem

-- | Floating-point roundToIntegral. Rounds a floating-point number
-- to the closest integer, again represented as a floating-point
-- number.
mkFpaRoundToIntegral :: Context -> AST -> AST -> IO AST
mkFpaRoundToIntegral = liftFun2 z3_mk_fpa_round_to_integral

-- | Minimum of floating-point numbers.
mkFpaMin :: Context -> AST -> AST -> IO AST
mkFpaMin = liftFun2 z3_mk_fpa_min

-- | Maximum of floating-point numbers.
mkFpaMax :: Context -> AST -> AST -> IO AST
mkFpaMax = liftFun2 z3_mk_fpa_max

-- | Floating-point less than or equal.
mkFpaLeq :: Context -> AST -> AST -> IO AST
mkFpaLeq = liftFun2 z3_mk_fpa_leq

-- | Floating-point less than.
mkFpaLt :: Context -> AST -> AST -> IO AST
mkFpaLt = liftFun2 z3_mk_fpa_lt

-- | Floating-point greater than or equal.
mkFpaGeq :: Context -> AST -> AST -> IO AST
mkFpaGeq = liftFun2 z3_mk_fpa_geq

-- | Floating-point greater than.
mkFpaGt :: Context -> AST -> AST -> IO AST
mkFpaGt = liftFun2 z3_mk_fpa_gt

-- | Floating-point equality.
mkFpaEq :: Context -> AST -> AST -> IO AST
mkFpaEq = liftFun2 z3_mk_fpa_eq

-- | Predicate indicating whether @t@ is a normal floating-point
-- number.
mkFpaIsNormal :: Context -> AST -> IO AST
mkFpaIsNormal = liftFun1 z3_mk_fpa_is_normal

-- | Predicate indicating whether @t@ is a subnormal floating-point
-- number.
mkFpaIsSubnormal :: Context -> AST -> IO AST
mkFpaIsSubnormal = liftFun1 z3_mk_fpa_is_subnormal

-- | Predicate indicating whether @t@ is a floating-point number
-- with zero value, i.e., +zero or -zero.
mkFpaIsZero :: Context -> AST -> IO AST
mkFpaIsZero = liftFun1 z3_mk_fpa_is_zero

-- | Predicate indicating whether @t@ is a floating-point number
-- representing infinity, i.e., +oo or -oo.
mkFpaIsInfinite :: Context -> AST -> IO AST
mkFpaIsInfinite = liftFun1 z3_mk_fpa_is_infinite

-- | Predicate indicating whether @t@ is NaN.
mkFpaIsNaN :: Context -> AST -> IO AST
mkFpaIsNaN = liftFun1 z3_mk_fpa_is_nan

-- | Predicate indicating whether @t@ is a negative floating-point
-- number.
mkFpaIsNegative :: Context -> AST -> IO AST
mkFpaIsNegative = liftFun1 z3_mk_fpa_is_negative

-- | Predicate indicating whether @t@ is a positive floating-point
-- number.
mkFpaIsPositive :: Context -> AST -> IO AST
mkFpaIsPositive = liftFun1 z3_mk_fpa_is_positive

-- | Conversion of a single IEEE 754-2008 bit-vector into a
-- floating-point number.
mkFpaToFpBv :: Context -> AST -> Sort -> IO AST
mkFpaToFpBv = liftFun2 z3_mk_fpa_to_fp_bv

-- | Conversion of a FloatingPoint term into another term of
-- different FloatingPoint sort.
mkFpaToFpFloat :: Context -> AST -> AST -> Sort -> IO AST
mkFpaToFpFloat = liftFun3 z3_mk_fpa_to_fp_float

-- | Conversion of a term of real sort into a term of
-- FloatingPoint sort.
mkFpaToFpReal :: Context -> AST -> AST -> Sort -> IO AST
mkFpaToFpReal = liftFun3 z3_mk_fpa_to_fp_real

-- | Conversion of a 2's complement signed bit-vector term into
-- a term of FloatingPoint sort.
mkFpaToFpSigned :: Context -> AST -> AST -> Sort -> IO AST
mkFpaToFpSigned = liftFun3 z3_mk_fpa_to_fp_signed

-- | Conversion of a 2's complement unsigned bit-vector term into
-- a term of FloatingPoint sort.
mkFpaToFpUnsigned :: Context -> AST -> AST -> Sort -> IO AST
mkFpaToFpUnsigned = liftFun3 z3_mk_fpa_to_fp_unsigned

-- | Conversion of a floating-point term into an unsigned bit-vector.
mkFpaToUbv :: Integral int => Context -> AST -> AST -> int -> IO AST
mkFpaToUbv = liftFun3 z3_mk_fpa_to_ubv

-- | Conversion of a floating-point term into a signed bit-vector.
mkFpaToSbv :: Integral int => Context -> AST -> AST -> int -> IO AST
mkFpaToSbv = liftFun3 z3_mk_fpa_to_sbv

-- | Conversion of a floating-point term into an real-numbered
-- term.
mkFpaToReal :: Context -> AST -> IO AST
mkFpaToReal = liftFun1 z3_mk_fpa_to_real

---------------------------------------------------------------------
-- Z3-specific floating-point extensions

-- | Retrieves the number of bits reserved for the exponent in a
-- FloatingPoint sort.
fpaGetEbits :: Integral int => Context -> Sort -> IO int
fpaGetEbits = liftFun1 z3_fpa_get_ebits

-- | Retrieves the number of bits reserved for the significand in
-- a FloatingPoint sort.
fpaGetSbits :: Integral int => Context -> Sort -> IO int
fpaGetSbits = liftFun1 z3_fpa_get_sbits

-- | Checks whether a given floating-point numeral is a NaN.
fpaIsNumeralNaN :: Context -> AST -> IO Bool
fpaIsNumeralNaN = liftFun1 z3_fpa_is_numeral_nan

-- | Checks whether a given floating-point numeral is a +oo or -oo.
fpaIsNumeralInf :: Context -> AST -> IO Bool
fpaIsNumeralInf = liftFun1 z3_fpa_is_numeral_inf

-- | Checks whether a given floating-point numeral is a +zero or
-- -zero.
fpaIsNumeralZero :: Context -> AST -> IO Bool
fpaIsNumeralZero = liftFun1 z3_fpa_is_numeral_zero

-- | Checks whether a given floating-point numeral is normal.
fpaIsNumeralNormal :: Context -> AST -> IO Bool
fpaIsNumeralNormal = liftFun1 z3_fpa_is_numeral_normal

-- | Checks whether a given floating-point numeral is subnormal.
fpaIsNumeralSubnormal :: Context -> AST -> IO Bool
fpaIsNumeralSubnormal = liftFun1 z3_fpa_is_numeral_subnormal

-- | Checks whether a given floating-point numeral is positive.
fpaIsNumeralPositive :: Context -> AST -> IO Bool
fpaIsNumeralPositive = liftFun1 z3_fpa_is_numeral_positive

-- | Checks whether a given floating-point numeral is negative.
fpaIsNumeralNegative :: Context -> AST -> IO Bool
fpaIsNumeralNegative = liftFun1 z3_fpa_is_numeral_negative

-- | Retrieves the sign of a floating-point literal as a bit-vector
-- expression.
fpaGetNumeralSignBv :: Context -> AST -> IO AST
fpaGetNumeralSignBv = liftFun1 z3_fpa_get_numeral_sign_bv

-- | Retrieves the significand of a floating-point literal as a
-- bit-vector expression.
fpaGetNumeralSignificandBv :: Context -> AST -> IO AST
fpaGetNumeralSignificandBv = liftFun1 z3_fpa_get_numeral_significand_bv

-- | Return the significand value of a floating-point numeral as a
-- string.
fpaGetNumeralSignificandString :: Context -> AST -> IO String
fpaGetNumeralSignificandString = liftFun1 z3_fpa_get_numeral_significand_string

-- | Return the exponent value of a floating-point numeral as a
-- string.
fpaGetNumeralExponentString :: Context -> AST -> Bool -> IO String
fpaGetNumeralExponentString = liftFun2 z3_fpa_get_numeral_exponent_string

-- | Retrieves the exponent of a floating-point literal as a
-- bit-vector expression.
fpaGetNumeralExponentBv :: Context -> AST -> Bool -> IO AST
fpaGetNumeralExponentBv = liftFun2 z3_fpa_get_numeral_exponent_bv

-- | Conversion of a floating-point term into a bit-vector term
-- in IEEE 754-2008 format.
mkFpaToIEEEBv :: Context -> AST -> IO AST
mkFpaToIEEEBv = liftFun1 z3_mk_fpa_to_ieee_bv

-- | Conversion of a real-sorted significand and an integer-sorted
-- exponent into a term of FloatingPoint sort.
mkFpaToFpIntReal :: Context -> AST -> AST -> AST -> Sort -> IO AST
mkFpaToFpIntReal = liftFun4 z3_mk_fpa_to_fp_int_real

---------------------------------------------------------------------
-- Optimization facilities

newtype Optimize = Optimize { unOptimize :: ForeignPtr Z3_optimize }
    deriving Eq

instance Marshal Optimize (Ptr Z3_optimize) where
  c2h = mkC2hRefCount Optimize z3_optimize_inc_ref z3_optimize_dec_ref
  h2c fp = withForeignPtr (unOptimize fp)

mkOptimize :: Context -> IO Optimize
mkOptimize = liftFun0 z3_mk_optimize

optimizeAssert :: Context -> Optimize -> AST -> IO ()
optimizeAssert = liftFun2 z3_optimize_assert

optimizeAssertAndTrack :: Context -> Optimize -> AST -> AST -> IO ()
optimizeAssertAndTrack = liftFun3 z3_optimize_assert_and_track

optimizeAssertSoft :: Context -> Optimize -> AST -> String -> Symbol -> IO Int
optimizeAssertSoft ctx opt ast str sym =
  marshal z3_optimize_assert_soft ctx $ \f ->
    h2c opt $ \optPtr ->
    h2c ast $ \astPtr ->
    withCString str $ \strPtr ->
    h2c sym $ \symPtr ->
      f optPtr astPtr strPtr symPtr

optimizeMaximize :: Context -> Optimize -> AST -> IO Int
optimizeMaximize = liftFun2 z3_optimize_maximize

optimizeMinimize :: Context -> Optimize -> AST -> IO Int
optimizeMinimize = liftFun2 z3_optimize_minimize

optimizePush :: Context -> Optimize -> IO ()
optimizePush = liftFun1 z3_optimize_push

optimizePop :: Context -> Optimize -> IO ()
optimizePop = liftFun1 z3_optimize_pop

optimizeCheck :: Context -> Optimize -> [AST] -> IO Result
optimizeCheck ctx opt ss = marshal z3_optimize_check ctx $ \f ->
  h2c opt $ \optPtr ->
  marshalArrayLen ss $ \ssNum ssPtr ->
    f optPtr ssNum ssPtr

optimizeGetReasonUnknown :: Context -> Optimize -> IO String
optimizeGetReasonUnknown = liftFun1 z3_optimize_get_reason_unknown

optimizeGetModel :: Context -> Optimize -> IO Model
optimizeGetModel = liftFun1 z3_optimize_get_model

optimizeGetUnsatCore :: Context -> Optimize -> IO [AST]
optimizeGetUnsatCore = liftFun1 z3_optimize_get_unsat_core

optimizeSetParams :: Context -> Optimize -> Params -> IO ()
optimizeSetParams = liftFun2 z3_optimize_set_params

optimizeGetLower :: Context -> Optimize -> Int -> IO AST
optimizeGetLower = liftFun2 z3_optimize_get_lower

optimizeGetUpper :: Context -> Optimize -> Int -> IO AST
optimizeGetUpper = liftFun2 z3_optimize_get_upper

optimizeGetUpperAsVector :: Context -> Optimize -> Int -> IO [AST]
optimizeGetUpperAsVector = liftFun2 z3_optimize_get_upper_as_vector

optimizeGetLowerAsVector :: Context -> Optimize -> Int -> IO [AST]
optimizeGetLowerAsVector = liftFun2 z3_optimize_get_lower_as_vector

optimizeToString :: Context -> Optimize -> IO String
optimizeToString = liftFun1 z3_optimize_to_string

optimizeFromString :: Context -> Optimize -> String -> IO ()
optimizeFromString = liftFun2 z3_optimize_from_string

optimizeFromFile :: Context -> Optimize -> String -> IO ()
optimizeFromFile = liftFun2 z3_optimize_from_file

optimizeGetHelp :: Context -> Optimize -> IO String
optimizeGetHelp = liftFun1 z3_optimize_get_help

optimizeGetAssertions :: Context -> Optimize -> IO [AST]
optimizeGetAssertions = liftFun1 z3_optimize_get_assertions

optimizeGetObjectives :: Context -> Optimize -> IO [AST]
optimizeGetObjectives = liftFun1 z3_optimize_get_objectives

-- AST vectors ?

-- AST maps ?

---------------------------------------------------------------------
-- Goals

-- TODO

---------------------------------------------------------------------
-- Tactics and Probes

-- TODO

---------------------------------------------------------------------
-- Solvers

-- | Solvers available in Z3.
--
-- These are described at <http://smtlib.cs.uiowa.edu/logics.html>
data Logic
  = AUFLIA
    -- ^ Closed formulas over the theory of linear integer arithmetic
    -- and arrays extended with free sort and function symbols but
    -- restricted to arrays with integer indices and values.

  | AUFLIRA
    -- ^ Closed linear formulas with free sort and function symbols over
    -- one- and two-dimentional arrays of integer index and real
    -- value.

  | AUFNIRA
    -- ^ Closed formulas with free function and predicate symbols over a
    -- theory of arrays of arrays of integer index and real value.

  | LRA
    -- ^ Closed linear formulas in linear real arithmetic.

  | QF_ABV
    -- ^ Closed quantifier-free formulas over the theory of bitvectors
    -- and bitvector arrays.

  | QF_AUFBV
    -- ^ Closed quantifier-free formulas over the theory of bitvectors
    -- and bitvector arrays extended with free sort and function
    -- symbols.

  | QF_AUFLIA
    -- ^ Closed quantifier-free linear formulas over the theory of
    -- integer arrays extended with free sort and function symbols.

  | QF_AX
    -- ^ Closed quantifier-free formulas over the theory of arrays with
    -- extensionality.

  | QF_BV
    -- ^ Closed quantifier-free formulas over the theory of fixed-size
    -- bitvectors.

  | QF_IDL
    -- ^ Difference Logic over the integers. In essence, Boolean
    -- combinations of inequations of the form x - y < b where x and y
    -- are integer variables and b is an integer constant.

  | QF_LIA
    -- ^ Unquantified linear integer arithmetic. In essence, Boolean
    -- combinations of inequations between linear polynomials over
    -- integer variables.

  | QF_LRA
    -- ^ Unquantified linear real arithmetic. In essence, Boolean
    -- combinations of inequations between linear polynomials over
    -- real variables.

  | QF_NIA
    -- ^ Quantifier-free integer arithmetic.

  | QF_NRA
    -- ^ Quantifier-free real arithmetic.

  | QF_RDL
    -- ^ Difference Logic over the reals. In essence, Boolean
    -- combinations of inequations of the form x - y < b where x and y
    -- are real variables and b is a rational constant.

  | QF_UF
    -- ^ Unquantified formulas built over a signature of uninterpreted
    -- (i.e., free) sort and function symbols.

  | QF_UFBV
    -- ^ Unquantified formulas over bitvectors with uninterpreted sort
    -- function and symbols.

  | QF_UFIDL
    -- ^ Difference Logic over the integers (in essence) but with
    -- uninterpreted sort and function symbols.

  | QF_UFLIA
    -- ^ Unquantified linear integer arithmetic with uninterpreted sort
    -- and function symbols.

  | QF_UFLRA
    -- ^ Unquantified linear real arithmetic with uninterpreted sort and
    -- function symbols.

  | QF_UFNRA
    -- ^ Unquantified non-linear real arithmetic with uninterpreted sort
    -- and function symbols.

  | UFLRA
    -- ^ Linear real arithmetic with uninterpreted sort and function
    -- symbols.

  | UFNIA
    -- ^ Non-linear integer arithmetic with uninterpreted sort and
    -- function symbols.

instance Show Logic where
  show AUFLIA    = "AUFLIA"
  show AUFLIRA   = "AUFLIRA"
  show AUFNIRA   = "AUFNIRA"
  show LRA       = "LRA"
  show QF_ABV    = "QF_ABV"
  show QF_AUFBV  = "QF_AUFBV"
  show QF_AUFLIA = "QF_AUFLIA"
  show QF_AX     = "QF_AX"
  show QF_BV     = "QF_BV"
  show QF_IDL    = "QF_IDL"
  show QF_LIA    = "QF_LIA"
  show QF_LRA    = "QF_LRA"
  show QF_NIA    = "QF_NIA"
  show QF_NRA    = "QF_NRA"
  show QF_RDL    = "QF_RDL"
  show QF_UF     = "QF_UF"
  show QF_UFBV   = "QF_UFBV"
  show QF_UFIDL  = "QF_UFIDL"
  show QF_UFLIA  = "QF_UFLIA"
  show QF_UFLRA  = "QF_UFLRA"
  show QF_UFNRA  = "QF_UFNRA"
  show UFLRA     = "UFLRA"
  show UFNIA     = "UFNIA"

mkSolver :: Context -> IO Solver
mkSolver = liftFun0 z3_mk_solver

mkSimpleSolver :: Context -> IO Solver
mkSimpleSolver = liftFun0 z3_mk_simple_solver

mkSolverForLogic :: Context -> Logic -> IO Solver
mkSolverForLogic c logic = mkStringSymbol c (show logic) >>= \sym ->
  toHsCheckError c $ \cPtr -> z3_mk_solver_for_logic cPtr $ unSymbol sym

-- | Return a string describing all solver available parameters.
solverGetHelp :: Context -> Solver -> IO String
solverGetHelp = liftFun1 z3_solver_get_help

-- | Set the given solver using the given parameters.
solverSetParams :: Context -> Solver -> Params -> IO ()
solverSetParams = liftFun2 z3_solver_set_params

solverPush :: Context -> Solver -> IO ()
solverPush = liftFun1 z3_solver_push

solverPop :: Context -> Solver -> Int -> IO ()
solverPop = liftFun2 z3_solver_pop

solverReset :: Context -> Solver -> IO ()
solverReset = liftFun1 z3_solver_reset

-- | Number of backtracking points.
solverGetNumScopes :: Context -> Solver -> IO Int
solverGetNumScopes = liftFun1 z3_solver_get_num_scopes

solverAssertCnstr :: Context -> Solver -> AST -> IO ()
solverAssertCnstr = liftFun2 z3_solver_assert

solverAssertAndTrack :: Context -> Solver -> AST -> AST -> IO ()
solverAssertAndTrack = liftFun3 z3_solver_assert_and_track

solverFromFile :: Context -> Solver -> String -> IO ()
solverFromFile = liftFun2 z3_solver_from_file

solverFromString :: Context -> Solver -> String -> IO ()
solverFromString = liftFun2 z3_solver_from_string

solverGetAssertions :: Context -> Solver -> IO [AST]
solverGetAssertions = liftFun1 z3_solver_get_assertions

-- | Check whether the assertions in a given solver are consistent or not.
solverCheck :: Context -> Solver -> IO Result
solverCheck ctx solver = marshal z3_solver_check ctx $ h2c solver

-- | Check whether the assertions in the given solver and optional assumptions are consistent or not.
solverCheckAssumptions :: Context -> Solver -> [AST] -> IO Result
solverCheckAssumptions ctx solver assump =
  marshal z3_solver_check_assumptions ctx $ \f ->
    h2c solver $ \solverPtr ->
    marshalArrayLen assump $ \assumpNum assumpArr ->
      f solverPtr assumpNum assumpArr

-- | Retrieve the model for the last 'solverCheck'.
--
-- The error handler is invoked if a model is not available because
-- the commands above were not invoked for the given solver,
-- or if the result was 'Unsat'.
solverGetModel :: Context -> Solver -> IO Model
solverGetModel ctx solver = marshal z3_solver_get_model ctx $ \f ->
  h2c solver $ \solverPtr ->
    f solverPtr

-- | Retrieve the proof for the last 'solverCheck' or 'solverCheckAssumptions'.
--
-- The error handler is invoked if a proof is not available because
-- the commands above were not invoked for the given solver,
-- or if the result was different from 'Unsat' (so 'Sat' does not have a proof).
solverGetProof :: Context -> Solver -> IO AST
solverGetProof = liftFun1 z3_solver_get_proof

-- | Retrieve the unsat core for the last 'solverCheckAssumptions'; the unsat core is a subset of the assumptions
solverGetUnsatCore :: Context -> Solver -> IO [AST]
solverGetUnsatCore = liftFun1 z3_solver_get_unsat_core

-- | Return a brief justification for an 'Unknown' result for the commands 'solverCheck' and 'solverCheckAssumptions'.
solverGetReasonUnknown :: Context -> Solver -> IO String
solverGetReasonUnknown = liftFun1 z3_solver_get_reason_unknown

-- | Convert the given solver into a string.
solverToString :: Context -> Solver -> IO String
solverToString = liftFun1 z3_solver_to_string

-------------------------------------------------
-- ** Helpers

-- | Call 'solverCheck' and based on the result also call 'solverGetModel'.
solverCheckAndGetModel :: Context -> Solver -> IO (Result, Maybe Model)
solverCheckAndGetModel ctx solver =
  do res <- solverCheck ctx solver
     mbModel <- case res of
                  Unsat -> return Nothing
                  _     -> Just <$> solverGetModel ctx solver
     return (res, mbModel)

---------------------------------------------------------------------
-- Marshalling

{- MARSHALLING HELPERS

We try to get rid of most of the marshalling boilerplate which, by the way,
is going to be essential for transitioning to Z3 4 API.

Most API functions can be lifted using 'liftFun'{0-3} helpers. Otherwise try
using 'marshal'. Worst case scenario, write the marshalling code yourself.

-}

-- withIntegral :: (Integral a, Integral b) => a -> (b -> r) -> r
-- withIntegral x f = f (fromIntegral x)

withContext :: Context -> (Ptr Z3_context -> IO r) -> IO r
withContext c f = Z3.RLock.with (lock c) $ withForeignPtr (unContext c) f

withContextError :: Context -> (Ptr Z3_context -> IO r) -> IO r
withContextError c f = withContext c $ \cPtr -> checkError cPtr (f cPtr)

marshalArray :: (Marshal h c, Storable c) => [h] -> (Ptr c -> IO a) -> IO a
marshalArray hs f = hs2cs hs $ \cs -> withArray cs f

marshalArrayLen :: (Marshal h c, Storable c, Integral i) =>
    [h] -> (i -> Ptr c -> IO a) -> IO a
marshalArrayLen hs f =
  hs2cs hs $ \cs -> withArrayLen cs $ \n -> f (fromIntegral n)

-- marshalMaybeArray :: (Marshal h c, Storable c) => Maybe [h] -> (Ptr c -> IO a) -> IO a
-- marshalMaybeArray Nothing   f = f nullPtr
-- marshalMaybeArray (Just hs) f = marshalArray hs f

liftAstN_err :: String
            -> (Ptr Z3_context -> CUInt -> Ptr (Ptr Z3_ast) -> IO (Ptr Z3_ast))
            -> Context -> [AST] -> IO AST
liftAstN_err s _ _ [] = error s
liftAstN_err _ f c es = marshal f c $ marshalArrayLen es
{-# INLINE liftAstN_err #-}

liftAstN :: (Ptr Z3_context -> IO (Ptr Z3_ast))
         -> (Ptr Z3_context -> CUInt -> Ptr (Ptr Z3_ast) -> IO (Ptr Z3_ast))
         -> Context -> [AST] -> IO AST
liftAstN s f c = maybe (liftFun0 s c) (liftAstN1 f c) . nonEmpty
{-# INLINE liftAstN #-}

liftAstN1 :: (Ptr Z3_context -> CUInt -> Ptr (Ptr Z3_ast) -> IO (Ptr Z3_ast))
          -> Context -> NonEmpty AST -> IO AST
liftAstN1 f c = marshal f c . marshalArrayLen . toList
{-# INLINE liftAstN1 #-}

class Marshal h c where
  c2h :: Context -> c -> IO h
  h2c :: h -> (c -> IO r) -> IO r

hs2cs :: Marshal h c => [h] -> ([c] -> IO r) -> IO r
hs2cs []     f = f []
hs2cs (h:hs) f =
  h2c h $ \c ->
  hs2cs hs $ \cs -> f (c:cs)

cs2hs :: Marshal h c => Context -> [c] -> IO [h]
cs2hs ctx = mapM (c2h ctx)

-- peekToHs :: (Marshal h c, Storable c) => Context -> Ptr c -> IO h
-- peekToHs c ptr = c2h c =<< peek ptr

-- peekToMaybeHs :: (Marshal h (Ptr c), Storable c) => Context -> Ptr (Ptr c) -> IO (Maybe h)
-- peekToMaybeHs c = peek >=> (c2h c `T.traverse`) . ptrToMaybe

peekArrayToHs :: (Marshal h c, Storable c) => Context -> Int -> Ptr c -> IO [h]
peekArrayToHs c n dPtr =
  cs2hs c =<< peekArray n dPtr

-- peekPtrArrayToHs :: (Marshal h c, Storable c) => Context -> Int -> Ptr (Ptr c) -> IO [h]
-- peekPtrArrayToHs c n = peekArray n >=> mapM (peekToHs c)

toHsCheckError :: Marshal h c => Context -> (Ptr Z3_context -> IO c) -> IO h
toHsCheckError c f = withContext c $ \cPtr ->
  c2h c =<< checkError cPtr (f cPtr)

type Z3SetRefCount c = Ptr Z3_context -> Ptr c -> IO ()
type Z3IncRefFun c = Z3SetRefCount c
type Z3DecRefFun c = Z3SetRefCount c

mkC2hRefCount :: (ForeignPtr c -> h)
                   -> Z3IncRefFun c
                   -> Z3DecRefFun c
                   -> Context -> Ptr c -> IO h
mkC2hRefCount mk incRef decRef ctx xPtr =
  withContext ctx $ \ctxPtr -> do
    incRef ctxPtr xPtr
    contextIncRef ctx
    let xFinalizer = Z3.RLock.with (lock ctx) $ (do decRef ctxPtr xPtr
                                                    contextDecRef ctxPtr (refCount ctx))
    mk <$> newForeignPtr xPtr xFinalizer

dummy_inc_ref :: Z3IncRefFun c
dummy_inc_ref _ _ = return ()

on_ast_ptr :: Z3SetRefCount Z3_ast
            -> (Ptr Z3_context -> Ptr a -> IO (Ptr Z3_ast))
            -> Z3SetRefCount a
f `on_ast_ptr` t = \ctxPtr ptr -> f ctxPtr =<< t ctxPtr ptr

instance Marshal h (Ptr x) => Marshal (Maybe h) (Ptr x) where
  c2h c = T.mapM (c2h c) . ptrToMaybe
  h2c Nothing  f = f nullPtr
  h2c (Just x) f = h2c x f

instance Marshal () () where
  c2h _ = return
  h2c x f = f x

instance Marshal Bool Bool where
  c2h _ = return
  h2c x f = f x

instance Marshal Result Z3_lbool where
  c2h _ = return . toResult
  h2c = error "Marshal Result Z3_lbool => h2c not implemented"

instance Integral h => Marshal h CInt where
  c2h _ = return . fromIntegral
  h2c i f = f (fromIntegral i)

instance Integral h => Marshal h CUInt where
  c2h _ = return . fromIntegral
  h2c i f = f (fromIntegral i)

instance Integral h => Marshal h CLong where
  c2h _ = return . fromIntegral
  h2c i f = f (fromIntegral i)

instance Integral h => Marshal h CULong where
  c2h _ = return . fromIntegral
  h2c i f = f (fromIntegral i)

instance Integral h => Marshal h CLLong where
  c2h _ = return . fromIntegral
  h2c i f = f (fromIntegral i)

instance Integral h => Marshal h CULLong where
  c2h _ = return . fromIntegral
  h2c i f = f (fromIntegral i)

instance Marshal Float CFloat where
  c2h _ = return . realToFrac
  h2c d f = f (realToFrac d)

instance Marshal Double CDouble where
  c2h _ = return . realToFrac
  h2c d f = f (realToFrac d)

instance Marshal String CString where
  c2h _ = peekCString
  h2c   = withCString

instance Marshal Context (Ptr Z3_context) where
  c2h _ ctx = withConfig $ mkContextWith (const (return ctx))
  h2c ctx = withForeignPtr (unContext ctx)

instance Marshal App (Ptr Z3_app) where
  c2h = mkC2hRefCount App
            (z3_inc_ref `on_ast_ptr` z3_app_to_ast)
            (z3_dec_ref `on_ast_ptr` z3_app_to_ast)
  h2c app = withForeignPtr (unApp app)

instance Marshal Params (Ptr Z3_params) where
  c2h = mkC2hRefCount Params z3_params_inc_ref z3_params_dec_ref
  h2c prm = withForeignPtr (unParams prm)

instance Marshal Symbol (Ptr Z3_symbol) where
  c2h _ = return . Symbol
  h2c s f = f (unSymbol s)

instance Marshal AST (Ptr Z3_ast) where
  c2h = mkC2hRefCount AST z3_inc_ref z3_dec_ref
  h2c a f = withForeignPtr (unAST a) f

instance Marshal [AST] (Ptr Z3_ast_vector) where
  c2h ctx vecPtr = withContext ctx $ \ctxPtr -> do
    z3_ast_vector_inc_ref ctxPtr vecPtr
    n <- z3_ast_vector_size ctxPtr vecPtr
    res <- if n == 0 -- Need an explicit check, since n is unsigned so n - 1 might overflow
              then return []
              else mapM (\i -> z3_ast_vector_get ctxPtr vecPtr i >>= c2h ctx) [0 .. (n - 1)]
    z3_ast_vector_dec_ref ctxPtr vecPtr
    return res
  h2c _ _ = error "Marshal [AST] (Ptr Z3_ast_vector) => h2c not implemented"

instance Marshal Sort (Ptr Z3_sort) where
  c2h = mkC2hRefCount Sort
            (z3_inc_ref `on_ast_ptr` z3_sort_to_ast)
            (z3_dec_ref `on_ast_ptr` z3_sort_to_ast)
  h2c srt = withForeignPtr (unSort srt)

instance Marshal FuncDecl (Ptr Z3_func_decl) where
  c2h = mkC2hRefCount FuncDecl
            (z3_inc_ref `on_ast_ptr` z3_func_decl_to_ast)
            (z3_dec_ref `on_ast_ptr` z3_func_decl_to_ast)
  h2c fnd = withForeignPtr (unFuncDecl fnd)

instance Marshal FuncEntry (Ptr Z3_func_entry) where
  c2h = mkC2hRefCount FuncEntry z3_func_entry_inc_ref
                                z3_func_entry_dec_ref
  h2c fne = withForeignPtr (unFuncEntry fne)

instance Marshal FuncInterp (Ptr Z3_func_interp) where
  c2h = mkC2hRefCount FuncInterp z3_func_interp_inc_ref
                                 z3_func_interp_dec_ref
  h2c fni = withForeignPtr (unFuncInterp fni)

instance Marshal Model (Ptr Z3_model) where
  c2h = mkC2hRefCount Model z3_model_inc_ref z3_model_dec_ref
  h2c m = withForeignPtr (unModel m)

instance Marshal Pattern (Ptr Z3_pattern) where
  c2h = mkC2hRefCount Pattern
            (z3_inc_ref `on_ast_ptr` z3_pattern_to_ast)
            (z3_dec_ref `on_ast_ptr` z3_pattern_to_ast)
  h2c pat = withForeignPtr (unPattern pat)

instance Marshal Constructor (Ptr Z3_constructor) where
  c2h = mkC2hRefCount Constructor dummy_inc_ref z3_del_constructor
  h2c cns = withForeignPtr (unConstructor cns)

instance Marshal ConstructorList (Ptr Z3_constructor_list) where
  c2h = mkC2hRefCount ConstructorList dummy_inc_ref z3_del_constructor_list
  h2c cl = withForeignPtr (unConstructorList cl)

instance Marshal Solver (Ptr Z3_solver) where
  c2h = mkC2hRefCount Solver z3_solver_inc_ref z3_solver_dec_ref
  h2c slv = withForeignPtr (unSolver slv)

instance Marshal Tactic (Ptr Z3_tactic) where
  c2h = mkC2hRefCount Tactic z3_tactic_inc_ref z3_tactic_dec_ref
  h2c tac = withForeignPtr (unTactic tac)

instance Marshal ApplyResult (Ptr Z3_apply_result) where
  c2h = mkC2hRefCount ApplyResult z3_apply_result_inc_ref z3_apply_result_dec_ref
  h2c apl = withForeignPtr (unApplyResult apl)

instance Marshal Goal (Ptr Z3_goal) where
  c2h = mkC2hRefCount Goal z3_goal_inc_ref z3_goal_dec_ref
  h2c goa = withForeignPtr (unGoal goa)

marshal :: Marshal rh rc => (Ptr Z3_context -> t) ->
              Context -> (t -> IO rc) -> IO rh
marshal f c cont = toHsCheckError c $ \cPtr -> cont $ f cPtr

liftFun0 :: Marshal rh rc => (Ptr Z3_context -> IO rc) ->
              Context -> IO rh
liftFun0 = flip toHsCheckError
{-# INLINE liftFun0 #-}

liftFun1 :: (Marshal ah ac, Marshal rh rc) =>
              (Ptr Z3_context -> ac -> IO rc) ->
              Context -> ah -> IO rh
liftFun1 f c x = h2c x $ \a ->
  toHsCheckError c $ \cPtr -> f cPtr a
{-# INLINE liftFun1 #-}

liftFun2 :: (Marshal ah ac, Marshal bh bc, Marshal rh rc) =>
              (Ptr Z3_context -> ac -> bc -> IO rc) ->
              Context -> ah -> bh -> IO rh
liftFun2 f c x y = h2c x $ \a -> h2c y $ \b ->
  toHsCheckError c $ \cPtr -> f cPtr a b
{-# INLINE liftFun2 #-}

liftFun3 :: (Marshal ah ac, Marshal bh bc, Marshal ch cc, Marshal rh rc) =>
              (Ptr Z3_context -> ac -> bc -> cc -> IO rc) ->
              Context -> ah -> bh -> ch -> IO rh
liftFun3 f c x y z = h2c x $ \x1 -> h2c y $ \y1 -> h2c z $ \z1 ->
  toHsCheckError c $ \cPtr -> f cPtr x1 y1 z1
{-# INLINE liftFun3 #-}

liftFun4 :: (Marshal ah ac, Marshal bh bc, Marshal ch cc, Marshal dh dc,
            Marshal rh rc) => (Ptr Z3_context -> ac -> bc -> cc -> dc ->
                               IO rc) ->
            Context -> ah -> bh -> ch -> dh -> IO rh
liftFun4 f c x y z zz = h2c x $ \x1 -> h2c y $ \y1 -> h2c z $ \z1 ->
  h2c zz $ \zz1 -> toHsCheckError c $ \cPtr -> f cPtr x1 y1 z1 zz1
{-# INLINE liftFun4 #-}

---------------------------------------------------------------------
-- Utils

-- | Convert 'Z3_lbool' from Z3.Base.C to 'Result'
toResult :: Z3_lbool -> Result
toResult lb
    | lb == z3_l_true  = Sat
    | lb == z3_l_false = Unsat
    | lb == z3_l_undef = Undef
    | otherwise        = error "Z3.Base.toResult: illegal `Z3_lbool' value"

-- | Wraps a non-null pointer with 'Just', or else returns 'Nothing'.
ptrToMaybe :: Ptr a -> Maybe (Ptr a)
ptrToMaybe ptr | ptr == nullPtr = Nothing
               | otherwise      = Just ptr
