# (PART) Object oriented programming {-}



# Introduction {#oo}

In the following five chapters you'll learn about __object oriented programming__ (OOP) in R. \index{object-oriented programming} OOP in R is a little more challenging than in other languages, because:

* There are multiple OOP systems to choose between. In this book, I'll focus 
  on the three that are most important in my opinion: S3, S4, and R6.

* S3 and S4 come from a very different heritage than the OOP found in most
  other popular languages. This means your existing OOP skills are unlikely
  to be of much help.

Indeed, for day-to-day use of R, FP is much more important than OOP. There are three main reasons to learn OOP:

* Learning a little S3 allows your functions to return richer results 
  that have a user friendly display and programmer friendly internals.
  It also defines syntactic standards can apply across multiple packages.
  This is why S3 is used throughout base R.

* Investing in S4 can be helpful for building up large systems that evolve
  over many years and are written by many programmers. This is why the
  Bioconductor project uses S4 as fundamental infrastructure.
  
* Mastering R6 gives you a standard way to escape R's copy-on-modify semantics
  when needed. This is particularly important if you want to model
  real-world objects that change over time.
  
This chapter will give you a rough lay of the land, and a field guide to help you identify OOP systems in the wild. The following four chapters (Base types, S3, S4, and R6) will dive into the details, starting with R's base types. These are not technically an OOP system, but they're important to understand because they're the fundamental building block of the true OOP systems.

## OOP Systems

We'll begin with an info dump of vocabulary and terminology. Don't worry if it doesn't stick. We'll come back to these ideas multiple times in the subsequent chapters.

Central to any OOP system are the concepts of class and method. A __class__ defines the behaviour of a set of __objects__, or instances, by describing their attributes and their relationship to other classes. The class is also used when selecting __methods__, functions that behave differently depending on the class of their input. A class defines what something _is_ and methods describe what something can _do_.

Classes are usually organised in a hierarchy: if a method does not exist for a child, then the parent's method is used instead. This means that a child class will __inherit__ behaviour from the parent class. Inheritance is one of the most important parts of OOP because it allows you to reduce the amount of code you have to write.

Following the notation of _Extending R_, there are two main styles of OOP:

*   In __encapsulated__ OOP, methods belong to objects or classes. This is 
    the most common paradigm in modern programming languages, and method calls
    typically look like `object.method`. This is called encapsulated because
    the object encapsulates all its metadata.
    
*   In __functional__ OOP, methods belong to functions called __generics__.
    Method calls look like ordinary function calls: `generic(object)`. This
    is called functional because from the outside it just looks like function 
    calls.
    
## OOP in R

Base R provides three OOP systems: S3, S4, and reference classes (RC):

*   __S3__ is R's first OOP system, and is described _Statistical Models 
    in S_ (1991). It informally implements the functional style.
    It provides no ironclad guarantees but instead relies on a set of 
    conventions. This makes it easy to get started with, and a low cost way 
    of solving many simple problems.

*   __S4__ is similar to S3, but much more formal. It was introduced in 
    _Programming with Data_ (1998). It requires more upfront work and in 
    return provides greater consistency. S4 is implemented
    in the __methods__ package, which is attached by default. The only
    package in base R to make use of S4 is stats4.
    
    (You might wonder if S1 and S2 exist. They don't: S3 and S4 were named 
    according to the versions of S that they accompanied.)

*   __RC__ implements encapsulated OO. RC objects are also mutable: they don't
    use R's usual copy-on-modify semantics, but are modified in place. This 
    makes them harder to reason about, but allows them to solve problems that 
    are difficult to solve with S3 or S4.

There are a number other OOP systems provided by packages. Three of the most popular are:

*   __R6__ implements encapsulated OOP like RC, but resolves some important 
    issues. You'll learn R6 instead of RC in this book. More on why later.
    
*   __R.oo__ provides some formalism on top of S3, and makes it possible to
    have mutable S3 objects.

*   __proto__ implements another style of OOP, called prototype based. It
    blurs the distinctions between classes and instances of classes (objects).
    There is some more information about prototype based programming 
    <http://vita.had.co.nz/papers/mutatr.html>.

Most OO systems in external packages are primarily of academic interest: they will help you understand the spectrum of OOP better, and can make it easier to solve certain classes of problems. However, they come with a big drawback: few R users know and understand them, so it is hard for others to read and contribute to your code.

## Field guide 

Before we go on to discuss base types, S3, S4, and R6 in more detail I want to introduce the sloop package:


```r
# install_github("hadley/sloop")
library(sloop)
```

The sloop package (think sail the seas of OOP in R) provides a number of helpers to fill in missing pieces in base R. The first helper to know about is `sloop::otype()`. It makes it easy to figure what OOP system an object found in the wild uses: 


```r
otype(1:10)
#> [1] "base"

otype(mtcars)
#> [1] "S3"

mle_obj <- stats4::mle(function(x = 1) (x - 2) ^ 2)
otype(mle_obj)
#> [1] "S4"
```

Without `otype()`, you need to work your way through the base functions:

* `is.object()` distinguishes between base types (`FALSE`) and 
  everything else (`TRUE`).
  
* `isS4()` distinguishes between S3 and S4.

* `inherits()` lets you figure out if you have an R6 object (an S3 object
   that inherits from "R6") or an RC object (an S4 object that inherits from
   "refClass").
