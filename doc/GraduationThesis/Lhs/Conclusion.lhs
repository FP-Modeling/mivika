Chapters 2 and 3 explained the bridge between software and the mathematical world of differential equations. As a follow-up, chapter 4 raised intuition and practical understanding of \texttt{Rivika} via a detailed walkthrough of an example. Chapters 5 and 6 identified some problems with the current implementation, such as lack of performance and the sampling issue, and addressed both problems via caching and interpolation. This chapter, \textit{Conclusion}, draws future improvements that can bring \texttt{Rivika} to a higher level of abstraction and some final conclusions about the project.

\section{Future Improvements}

In regards of numerical methods, one of the immediate improvements would be to use \textbf{adaptive} size for the solver time step that \textbf{change dynamically} in run time. This strategy controls the errors during calculations using the derivative by adapting the size of the time step. Hence, it starts backtracking previous steps with smaller time steps until some error threshold is satisfied, thus providing finer and granular control to the numerical methods, coping with approximation errors due to larger time steps.

In terms of the used technology, some ideas come to mind related to abstracting out duplicated\textbf{patterns} across the code base. The proposed software used a mix of high level abstractions, such as algebraic types and typeclasses, with some low level abstractions, e.g., explicit memory manipulation. An immediate improvement related to this topic would be to abstract the \textbf{stage} inside the solver information using a sum type, \texttt{Stage}, thus removing the use of negative and positive numbers as the trigger for interpolation. On the same line of leveraging abstractions, another major improvement for \texttt{Rivika} would be to make it entirely \textbf{pure}, meaning that all the necessary side effects would be handled \textbf{only} by high level abstractions concepts internally. For instance, the memory allocated via \texttt{IORef} to save computed values acts as a \textbf{state} of the numerical solver; this could be refactored to use the \texttt{State} monad~\footnote{\texttt{ST} Monad \href{https://wiki.haskell.org/State\_Monad}{\textcolor{blue}{wiki page}}.} This monad deals with state management by itself, removing this weight from the developer.

Further, with the removal of \texttt{IORef}~\footnote{\texttt{IORef} \href{https://hackage.haskell.org/package/base-4.16.1.0/docs/Data-IORef.html}{\textcolor{blue}{hackage documentation}}.} type from the project, the next step would be to change the \texttt{Dynamics} type to not include in its definition the \texttt{IO} monad. As we saw in chapters 2 and 3, this type is heavily coupled to functions that deal with \texttt{IORef} type, such as providing a pointer to a memory region. Moreover, because \texttt{IO} was involved, the typeclass \texttt{MonadIO} became a requirement, given that we need to transition from it to the \texttt{Dynamics} monad in a few situations, like in the \textit{newInteg} function. As a middle step before achieving an implementation based on the \texttt{ST} monad, \textbf{monad transformers}~\footnote{Monad Transformers \href{https://en.wikibooks.org/wiki/Haskell/Monad\_transformers}{\textcolor{blue}{wiki page}}.} provides a more elegant alternative to go back and forth between monads, removing the need for the \texttt{MonadIO} typeclass.

The \texttt{Dynamics} type, which is a function from \texttt{Parameters} to \texttt{IO a}, resembles the \texttt{Reader} monad~\footnote{\texttt{Reader} Monad \href{https://hackage.haskell.org/package/mtl-2.2.2/docs/Control-Monad-Reader.html}{\textcolor{blue}{hackage documentation}}.}, a monad that captures the notion of functions. Across the implementation a lot of intermediate dynamic computations are being created and in the majority of these steps the same record of \texttt{Parameters} is being applied in sequence, creating a chain of functions that are passing the same parameter to one another. By using the \texttt{Reader} monad, this pattern could be abstracted out from the program. This idea, when combined with the \texttt{State} monad initiative, indicates that the \texttt{RWS} monad~\footnote{\texttt{RWS} Monad \href{https://hackage.haskell.org/package/mtl-2.2.2/docs/Control-Monad-RWS-Lazy.html}{\textcolor{blue}{hackage documentation}}.}, a monad that combines the monads \texttt{Reader}, \texttt{Writer} and \texttt{State}, may be the final goal for a completely pure but effective solution.

Also, there's GPAC and its mapping to Haskell features. As explained previously, some basic units of GPAC are being modeled by the \texttt{Num} typeclass, present in Haskell's \texttt{Prelude} module. By using more specific and customized numerical typeclasses~\footnote{Examples of \href{https://guide.aelve.com/haskell/alternative-preludes-zr69k1hc}{\textcolor{blue}{alternative preludes}}.}, it might be possible to better express these basic units and take advantage of better performance and convenience that these alternatives provide.

Finally, there's the \texttt{MonadFix} typeclass~\cite{Levent1, Levent2, Levent3}~\footnote{\texttt{MonadFix} Monad \href{https://hackage.haskell.org/package/base-4.16.1.0/docs/Control-Monad-Fix.html}{\textcolor{blue}{hackage documentation}}.}~\footnote{\texttt{MonadFix} Monad \href{https://wiki.haskell.org/MonadFix}{\textcolor{blue}{wiki page}}.}; an implemented typeclass used in more recent versions of \texttt{Aivika}. This typeclass uses the mathematical definition of the \textit{fixed-point} concept to compute monadic operations, i.e., it makes it possible to compute the \textbf{fix point} of a computation while being wrapped in a monad, thus being useful for creating loopbacks~\footnote{\texttt{MonadFix} Monad \href{https://github.com/FP-Modeling/fixingAnalog}{\textcolor{blue}{example of use case}}.} within the monad. As the final result, this typeclass abstracts out the \texttt{Integrator} type, meaning that the manipulation of the integrator is no longer maintained by the developer. This shrink in the DSL removes the similarities of the implementation with the GPAC model in some degree, given that the integrator is now implicit. The code below is the same Lorenz Attractor example previously used, but written with this improved implementation. The main differences are: the absence of the integrator explicitly, the existence of another type that encapsulates the \texttt{Dynamics} type, so-called \texttt{Simulation}, and the use of \texttt{mdo-notation}, also known as \textit{recursive do-notation}~\footnote{Recursive \texttt{do-notation} \href{https://ghc.gitlab.haskell.org/ghc/doc/users\_guide/exts/recursive\_do.html}{\textcolor{blue}{GHC documentation}}.}, rather than \texttt{do-notation}:

\begin{spec}
lorenzModel :: Simulation [IO [Double]]
lorenzModel = 
  mdo x <- integ (sigma * (y - x)) 1.0
      y <- integ (x * (rho - z) - y) 1.0
      z <- integ (x * y - beta * z) 1.0
      let sigma = 10.0
          rho = 28.0
          beta = 8.0 / 3.0
      runDynamicsInIntegTimes $ sequence [x, y, z]
\end{spec}

\section{Final Thoughts}

When Shannon proposed a formal foundation for the Differential Analyzer~\cite{Shannon}, mathematical abstractions were leveraged to model continuous time. However, after the transistor era, a new set of concepts that lack this formal basis was developed, and some of which crippled our capacity of simulating reality. Later, the need for some formalism made a comeback for modeling physical phenomena with abstractions that take \textit{time} into consideration. Models of computation~\cite{LeeModeling, LeeChallenges, LeeComponent, LeeSangiovanni} and the ForSyDe framework~\cite{Sander2017, Seyed2020} are examples of this change in direction. Nevertheless, Shannon's original idea is now being discussed again with some improvements~\cite{Graca2003, Graca2004, Graca2016} and being transposed to high level programming languages in the hybrid system domain~\cite{Edil2018}.

The \texttt{Rivika} EDSL~\footnote{\texttt{Rivika} \href{https://github.com/FP-Modeling/rivika}{\textcolor{blue}{source code}}.} follows this path of bringing CPS simulation to the highest level of abstraction, via the Haskell programming language, but still taking into account a formal background inspired by the GPAC model. The software uses advanced functional programming techniques to solve differential equations, mapping the abstractions to FF-GPAC's analog units. Although still limited by the discrete nature of numerical methods, the solution is performant and accurate enough for studies in the cyber-physical domain.
