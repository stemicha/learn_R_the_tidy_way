# Translating R code {#translation}



The combination of first class environments, lexical scoping, and metaprogramming gives us a powerful toolkit for translating R code in to other languages. One fully-fledged example of this idea is dbplyr. dbplyr powers the database backends for dplyr, allowing to express data maniplation in R and automatically translating it in to SQL. An important part of dbplyr is `translate_sql()` which turns vector R code in to the equivalent SQL:


```r
library(dbplyr)
translate_sql(x ^ 2)
#> <SQL> POWER("x", 2.0)
translate_sql(x < 5 & !is.na(x))
#> <SQL> "x" < 5.0 AND NOT((("x") IS NULL))
translate_sql(!first %in% c("John", "Roger", "Robert"))
#> <SQL> NOT("first" IN ('John', 'Roger', 'Robert'))
translate_sql(select == 7)
#> <SQL> "select" = 7.0
```

This chapter will develop two simple, but useful DSLs: one to generate HTML, and the other to turn mathematical expressions from R code into LaTeX.

<!-- ##### Prerequisites -->

This chapter together pulls together many techniques discussed elsewhere in the book. In particular, you'll need to understand environments, metaprogramming, and a little functional programming and S3. We'll use rlang for its metaprogramming tools, and purrr for its mapping functions


```r
library(rlang)
library(purrr)
#> 
#> Attaching package: 'purrr'
#> The following objects are masked from 'package:rlang':
#> 
#>     %@%, %||%, as_function, flatten, flatten_chr, flatten_dbl,
#>     flatten_int, flatten_lgl, invoke, list_along, modify, prepend,
#>     rep_along, splice
```

## HTML {#html}

HTML (hypertext markup language) is the language that underlies the majority of the web. It's a special case of SGML (standard generalised markup language), and it's similar but not identical to XML (extensible markup language). HTML looks like this: \index{HTML}

```html
<body>
  <h1 id='first'>A heading</h1>
  <p>Some text &amp; <b>some bold text.</b></p>
  <img src='myimg.png' width='100' height='100' />
</body>
```

Even if you've never looked at HTML before, you can still see that the key component of its coding structure is tags: `<tag></tag>`. Tags can be nested within other tags and intermingled with text. There are over 100 HTML tags, but in this chapter we'll focus on just a handful:

* `<body>` is the top-level tag that contains all content.
* `<h1>` defines a top level heading.
* `<p>` defines a paragraph.
* `<b>` emboldens text.
* `<img>` embeds an image.

Tags can also have named __attributes__ which look like `<tag name1='value1' name2='value2'></tag>`. Two important attributes used with just about every tag are `id` and `class`. These are used in conjunction with CSS (cascading style sheets) in order to control the visual appearance of the page.

__Void tags__, like `<img>`, don't have any content, are written `<img />`, not `<img></img>`. Since they have no content, attributes are more important, and  `img` has three that are used with almost every image: `src` (where the image lives), `width`, and `height`.

Because `<` and `>` have special meanings in HTML, you can't write them directly. Instead you have to use the HTML __escapes__: `&gt;` and `&lt;`. And, since those escapes use `&`, if you want a literal ampersand you have to escape it with `&amp;`.

### Goal

Our goal is to make it easy to generate HTML from R. To give a concrete example, we want to generate the following HTML:

```html
<body>
  <h1 id='first'>A heading</h1>
  <p>Some text &amp; <b>some bold text.</b></p>
  <img src='myimg.png' width='100' height='100' />
</body>
```

And we want the structure of the R code to match the structure of the HTML as closely as possible. To that end, we will work our way up to the following DSL:


```r
with_html(
  body(
    h1("A heading", id = "first"),
    p("Some text &", b("some bold text.")),
    img(src = "myimg.png", width = 100, height = 100)
  )
)
```

This DSL has the following the properties:

* The nesting of function calls matches the nesting of tags. 

* Unnamed arguments become the content of the tag, and named arguments 
  become their attributes. 
  
* We can automatically escape `&` and other special characters 
  because tags and text are clearly distinct.

### Escaping

Escaping is so fundamental to tranlsation that it'll be our first topic. There are two related challenges:

* In user input, we need to automatically escape `&`, `<` and `>`.

* At the same time we need to make sure that the `&`, `<` and `>` we generate
  are not double-escaped (i.e. to `&amp;amp;`, `&amp;lt;` and `&amp;gt;).
  
The easiest way to do this is to create an S3 class that distinguishes between regular text (that needs escaping) and HTML (that doesn't). \index{escaping}


```r
html <- function(x) structure(x, class = "advr_html")
cat_line <- function(...) cat(..., "\n", sep = "")

print.advr_html <- function(x, ...) {
  out <- paste0("<HTML> ", x)
  cat_line(paste(strwrap(out), collapse = "\n"))
}
```

We then write an escape method. It has two important methods:

* `escape.character()` takes a regular character vector and returns an HTML
  vector with special characters (`&`, `<`, `>`) escaped.
  
* `escape.html()` which leaves already escaped HTML as is.


```r
escape <- function(x) UseMethod("escape")

escape.character <- function(x) {
  x <- gsub("&", "&amp;", x)
  x <- gsub("<", "&lt;", x)
  x <- gsub(">", "&gt;", x)

  html(x)
}

escape.advr_html <- function(x) x
```

Now we check that it works


```r
escape("This is some text.")
#> <HTML> This is some text.
escape("x > 1 & y < 2")
#> <HTML> x &gt; 1 &amp; y &lt; 2

# Double escaping is not a problem
escape(escape("This is some text. 1 > 2"))
#> <HTML> This is some text. 1 &gt; 2

# And text we know is HTML doesn't get escaped.
escape(html("<hr />"))
#> <HTML> <hr />
```

Conveniently this also gives the user a way to opt-out of our escaping if they know the content is already escaped.

### Basic tag functions

Next, we'll write a few simple tag functions then figure out how to generalise this function to cover all possible tags. 

Let's start with `<p>`. HTML tags can have both attributes (e.g., id or class) and children (like `<b>` or `<i>`). We need some way of separating these in the function call. Given that attributes are named values and children don't have names, it seems natural to separate using named arguments from unnamed ones. For example, a call to `p()` might look like:


```r
p("Some text. ", b(i("some bold italic text")), class = "mypara")
```

We could list all the possible attributes of the `<p>` tag in the function definition. But that's hard not only because there are many attributes, but also because it's possible to use [custom attributes](http://html5doctor.com/html5-custom-data-attributes/). Instead, we'll just use `...` and separate the components based on whether or not they are named. With this in mind, we create a helper function that wraps around `rlang::dots_list()` (so we can use `!!` and `!!!`) and returns named and unnamed components separately:


```r
dots_partition <- function(...) {
  dots <- dots_list(...)

  is_named <- names(dots) != ""
  list(
    named = dots[is_named],
    unnamed = dots[!is_named]
  )
}

str(dots_partition(a = 1, 2, b = 3, 4))
#> List of 2
#>  $ named  :List of 2
#>   ..$ a: num 1
#>   ..$ b: num 3
#>  $ unnamed:List of 2
#>   ..$ : num 2
#>   ..$ : num 4
```

We can now create our `p()` function. Notice that there's one new function here: `html_attributes()`. It takes a named list and returns the HTML attibute specification as a string. It's a little complicated (in part, because it deals with some idiosyncracies of HTML that I haven't mentioned.), but it's not that important and doesn't introduce any programming new ideas, so I won't discuss it here (you can find the [source online](https://github.com/hadley/adv-r/blob/master/dsl-html-attributes.r)).


```r
source("dsl-html-attributes.r", local = TRUE)
p <- function(...) {
  dots <- dots_partition(...)
  attribs <- html_attributes(dots$named)
  children <- map_chr(dots$unnamed, escape)
  
  html(paste0(
    "<p", attribs, ">",
    paste(children, collapse = ""),
    "</p>"
  ))
}

p("Some text")
#> <HTML> <p>Some text</p>
p("Some text", id = "myid")
#> <HTML> <p id='myid'>Some text</p>
p("Some text", class = "important", `data-value` = 10)
#> <HTML> <p class='important' data-value='10'>Some text</p>
```

### Tag functions

It's straightforward to adapt `p()` to other tags: we just need to replace `"p"` with the name of the tag. One elegant way to do that is to manually create a function with `rlang::new_function()`, using unquoting with `paste0()` to generate the starting and ending tags.


```r
tag <- function(tag) {
  new_function(
    exprs(... = ),
    expr({
      dots <- dots_partition(...)
      attribs <- html_attributes(dots$named)
      children <- map_chr(dots$unnamed, escape)
  
      html(paste0(
        !!paste0("<", tag), attribs, ">",
        paste(children, collapse = ""),
        !!paste0("</", tag, ">")
      ))
    }),
    caller_env()
  )
}
tag("b")
#> function (...) 
#> {
#>     dots <- dots_partition(...)
#>     attribs <- html_attributes(dots$named)
#>     children <- map_chr(dots$unnamed, escape)
#>     html(paste0("<b", attribs, ">", paste(children, collapse = ""), 
#>         "</b>"))
#> }
```

Now we can run our earlier example:


```r
p <- tag("p")
b <- tag("b")
i <- tag("i")
p("Some text. ", b(i("some bold italic text")), class = "mypara")
#> <HTML> <p class='mypara'>Some text. <b><i>some bold italic
#> text</i></b></p>
```

Before we generate functions for every possible HTML tag, we need to create a variant of `tag()` for void tags. It's very similar to `tag()`, but it will throw an error if there are any unnamed tags, and the tag itself looks a little different.


```r
void_tag <- function(tag) {
  new_function(
    exprs(... = ), 
    expr({
      dots <- dots_partition(...)
      if (length(dots$unnamed) > 0) {
        stop(!!paste0("<", tag, "> must not have unnamed arguments"), call. = FALSE)
      }
      attribs <- html_attributes(dots$named)
  
      html(paste0(!!paste0("<", tag), attribs, " />"))
    }),
    caller_env()
  )
}

img <- void_tag("img")
img(src = "myimage.png", width = 100, height = 100)
#> <HTML> <img src='myimage.png' width='100' height='100' />
```

### Processing all tags

Next we need a list of all the HTML tags:


```r
tags <- c("a", "abbr", "address", "article", "aside", "audio", 
  "b","bdi", "bdo", "blockquote", "body", "button", "canvas", 
  "caption","cite", "code", "colgroup", "data", "datalist", 
  "dd", "del","details", "dfn", "div", "dl", "dt", "em", 
  "eventsource","fieldset", "figcaption", "figure", "footer", 
  "form", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", 
  "hgroup", "html", "i","iframe", "ins", "kbd", "label", 
  "legend", "li", "mark", "map","menu", "meter", "nav", 
  "noscript", "object", "ol", "optgroup", "option", "output", 
  "p", "pre", "progress", "q", "ruby", "rp","rt", "s", "samp", 
  "script", "section", "select", "small", "span", "strong", 
  "style", "sub", "summary", "sup", "table", "tbody", "td", 
  "textarea", "tfoot", "th", "thead", "time", "title", "tr",
  "u", "ul", "var", "video")

void_tags <- c("area", "base", "br", "col", "command", "embed",
  "hr", "img", "input", "keygen", "link", "meta", "param", 
  "source", "track", "wbr")
```

If you look at this list carefully, you'll see there are quite a few tags that have the same name as base R functions (`body`, `col`, `q`, `source`, `sub`, `summary`, `table`), and others that have the same name as popular packages (e.g., `map`). This means we don't want to make all the functions available by default, in either the global environment or in a package. Instead, we'll put them in a list and then provide a helper to make it easy to use them when desired. First, we make a named list:


```r
html_tags <- c(
  tags %>% set_names() %>% map(tag),
  void_tags %>% set_names() %>% map(void_tag)
)
```

This gives us an explicit (but verbose) way to call tag functions:


```r
html_tags$p(
  "Some text. ", 
  html_tags$b(html_tags$i("some bold italic text")), 
  class = "mypara"
)
#> <HTML> <p class='mypara'>Some text. <b><i>some bold italic
#> text</i></b></p>
```

We can then finish off our HTML DSL with a function that allows us to evaluate code in the context of that list. Here we slightly abuse the data mask, passing it a list of functions rather than a data frame. This is quick hack to mingle the execution environment of `code` with the functions in `html_tags`.


```r
with_html <- function(code) {
  code <- enquo(code)
  eval_tidy(code, html_tags)
}
```

This gives us a succinct API which allows us to write HTML when we need it but doesn't clutter up the namespace when we don't.


```r
with_html(
  body(
    h1("A heading", id = "first"),
    p("Some text &", b("some bold text.")),
    img(src = "myimg.png", width = 100, height = 100)
  )
)
#> <HTML> <body><h1 id='first'>A heading</h1><p>Some text
#> &amp;<b>some bold text.</b></p><img src='myimg.png' width='100'
#> height='100' /></body>
```

If you want to access the R function overridden by an HTML tag with the same name inside `with_html()`, you can use the full `package::function` specification.

### Exercises

1.  The escaping rules for `<script>` and `<style>` tags are different: you
    don't want to escape angle brackets or ampersands, but you do want to
    escape `</script>` or `</style>`.  Adapt the code above to follow these
    rules.

1.  The use of `...` for all functions has some big downsides. There's no
    input validation and there will be little information in the
    documentation or autocomplete about how they are used in the function. 
    Create a new function that, when given a named list of tags and their   
    attribute names (like below), creates functions which address this problem.

    
    ```r
    list(
      a = c("href"),
      img = c("src", "width", "height")
    )
    ```

    All tags should get `class` and `id` attributes.

1. Currently the HTML doesn't look terribly pretty, and it's hard to see the
   structure. How could you adapt `tag()` to do indenting and formatting?

1.  Reason about the following code that calls `with_html()` referening objects
    from the environment. Will it work or fail? Why? Run the code to 
    verify your predictions.
    
    
    ```r
    greeting <- "Hello!"
    with_html(p(greeting))
    
    address <- "123 anywhere street"
    with_html(p(address))
    ```
    

## LaTeX {#latex}

The next DSL will convert R expressions into their LaTeX math equivalents. (This is a bit like `?plotmath`, but for text instead of plots.) LaTeX is the lingua franca of mathematicians and statisticians: it's common to use LaTeX notation whenever you want to expression an equation in text (e.g., in an email). Since many reports are produced using both R and LaTeX, it might be useful to be able to automatically convert mathematical expressions from one language to the other. \index{LaTeX}

Because we need to convert both functions and names, this mathematical DSL will be more complicated than the HTML DSL. We'll also need to create a "default" conversion, so that functions we don't know about get a standard conversion. Like the HTML DSL, we'll also use metaprogramming to make it easier to generate the translators.

Can no longer just use eval: we also need to walk the tree. Ideally this would not be necessary. ObjectTables (see objectable package) almost make it possible to eliminate the tree walking but:

* They have currently have a big performance penalty

* There's no way to distinguish symbols used in for function calls vs. other
  symbols. 

Before we begin, let's quickly cover how formulas are expressed in LaTeX.

### LaTeX mathematics

The full spectrum of LaTeX mathematical notation is complex. Fortunately, they are [well documented](http://en.wikibooks.org/wiki/LaTeX/Mathematics), and the most common commands  have a fairly simple structure:

* Most simple mathematical equations are written in the same way you'd type
  them in R: `x * y`, `z ^ 5`. Subscripts are written using `_` (e.g., `x_1`).

* Special characters start with a `\`: `\pi` = ??, `\pm` = ??, and so on.
  There are a huge number of symbols available in LaTeX. Googling for
  `latex math symbols` will return many 
  [lists](http://www.sunilpatel.co.uk/latex-type/latex-math-symbols/). 
  There's even [a service](http://detexify.kirelabs.org/classify.html) that 
  will look up the symbol you sketch in the browser.

* More complicated functions look like `\name{arg1}{arg2}`. For example, to
  write a fraction you'd use `\frac{a}{b}`. To write a square root, you'd use 
  `\sqrt{a}`.

* To group elements together use `{}`: i.e., `x ^ a + b` vs. `x ^ {a + b}`.

* In good math typesetting, a distinction is made between variables and
  functions. But without extra information, LaTeX doesn't know whether
  `f(a * b)` represents calling the function `f` with input `a * b`,
  or is shorthand for `f * (a * b)`. If `f` is a function, you can tell
  LaTeX to typeset it using an upright font with `\textrm{f}(a * b)`.

### Goal

Our goal is to use these rules to automatically convert an R expression to its appropriate LaTeX representation. We'll tackle this in four stages:

* Convert known symbols: `pi` -> `\pi`

* Leave other symbols unchanged: `x` -> `x`, `y` -> `y`

* Convert known functions to their special forms: `sqrt(frac(a, b))` ->
  `\sqrt{\frac{a, b}}`

* Wrap unknown functions with `\textrm`: `f(a)` -> `\textrm{f}(a)`

We'll code this translation in the opposite direction of what we did with the HTML DSL. We'll start with infrastructure, because that makes it easy to experiment with our DSL, and then work our way back down to generate the desired output.

### `to_math`

To begin, we need a wrapper function that will convert R expressions into LaTeX math expressions. This will work similarly to `to_html()`: capture the unevaluated expression and evaluate it in a special environment. Two main differences:

* Environment is no longer constant It will vary depending on the expression. 
  We do this in order to be specially handle unknown symbols and functions

* Don't use quosure.


```r
to_math <- function(x) {
  expr <- enexpr(x)
  out <- eval_bare(expr, latex_env(expr))
  
  latex(out)
}

latex <- function(x) structure(x, class = "advr_latex")
print.advr_latex <- function(x) {
  cat_line("<LATEX> ", x)
}
```

### Known symbols

Our first step is to create an environment that will convert the special LaTeX symbols used for Greek, e.g., `pi` to `\pi`. We'll use the same basic trick as used by `subset` to make it possible to select column ranges by name (`subset(mtcars, , cyl:wt)`): bind a name to a string in a special environment.

We create that environment by naming a vector, converting the vector into a list, and converting the list into an environment.


```r
greek <- c(
  "alpha", "theta", "tau", "beta", "vartheta", "pi", "upsilon",
  "gamma", "varpi", "phi", "delta", "kappa", "rho",
  "varphi", "epsilon", "lambda", "varrho", "chi", "varepsilon",
  "mu", "sigma", "psi", "zeta", "nu", "varsigma", "omega", "eta",
  "xi", "Gamma", "Lambda", "Sigma", "Psi", "Delta", "Xi", 
  "Upsilon", "Omega", "Theta", "Pi", "Phi")
greek_list <- set_names(paste0("\\", greek), greek)
greek_env <- as_env(greek_list)
```

We can then check it:


```r
latex_env <- function(expr) {
  greek_env
}

to_math(pi)
#> <LATEX> \pi
to_math(beta)
#> <LATEX> \beta
```

Looks good so far!

### Unknown symbols

If a symbol isn't Greek, we want to leave it as is. This is tricky because we don't know in advance what symbols will be used, and we can't possibly generate them all. So we'll use the approach described in [walking the tree](#ast-funs). The `all_names` function takes an expression and does the following: if it's a name, it converts it to a string; if it's a call, it recurses down through its arguments.




```r
all_names_rec <- function(x) {
  switch_expr(x,
    constant = character(),
    symbol =   as.character(x),
    pairlist = ,
    call =     flat_map_chr(as.list(x[-1]), all_names)
  )
}

all_names <- function(x) {
  unique(all_names_rec(x))
}

all_names(expr(x + y + f(a, b, c, 10)))
#> [1] "x" "y" "a" "b" "c"
```

We now want to take that list of symbols, and convert it to an environment so that each symbol is mapped to its corresponding string representation (e.g., so `eval(quote(x), env)` yields `"x"`). We again use the pattern of converting a named character vector to a list, then converting the list to an environment.


```r
latex_env <- function(expr) {
  names <- all_names(expr)
  symbol_env <- as_env(set_names(names))

  symbol_env
}

to_math(x)
#> <LATEX> x
to_math(longvariablename)
#> <LATEX> longvariablename
to_math(pi)
#> <LATEX> pi
```

This works, but we need to combine it with the Greek symbols environment. Since we want to give preference to Greek over defaults (e.g., `to_math(pi)` should give `"\\pi"`, not `"pi"`), `symbol_env` needs to be the parent of `greek_env`. To do that, we need to make a copy of `greek_env` with a new parent. 

This gives us a function that can convert both known (Greek) and unknown symbols.


```r
latex_env <- function(expr) {
  # Unknown symbols
  names <- all_names(expr)
  symbol_env <- as_env(set_names(names))

  # Known symbols
  env_clone(greek_env, parent = symbol_env)
}

to_math(x)
#> <LATEX> x
to_math(longvariablename)
#> <LATEX> longvariablename
to_math(pi)
#> <LATEX> \pi
```

### Known functions

Next we'll add functions to our DSL. We'll start with a couple of helper closures that make it easy to add new unary and binary operators. These functions are very simple: they only assemble strings. (Again we use `force()` to make sure the arguments are evaluated at the right time.)


```r
unary_op <- function(left, right) {
  new_function(
    exprs(e1 = ),
    expr(
      paste0(!!left, e1, !!right)  
    ),
    caller_env()
  )
}

binary_op <- function(sep) {
  new_function(
    exprs(e1 = , e2 = ),
    expr(
      paste0(e1, !!sep, e2)  
    ),
    caller_env()
  )
}

unary_op("\\sqrt{", "}")
#> function (e1) 
#> paste0("\\sqrt{", e1, "}")
binary_op("+")
#> function (e1, e2) 
#> paste0(e1, "+", e2)
```

Using these helpers, we can map a few illustrative examples of converting R to LaTeX. Note that with R's lexical scoping rules helping us, we can easily provide new meanings for standard functions like `+`, `-`, and `*`, and even `(` and `{`.


```r
# Binary operators
f_env <- child_env(
  .parent = empty_env(),
  `+` = binary_op(" + "),
  `-` = binary_op(" - "),
  `*` = binary_op(" * "),
  `/` = binary_op(" / "),
  `^` = binary_op("^"),
  `[` = binary_op("_"),
  
  # Grouping
  `{` = unary_op("\\left{ ", " \\right}"),
  `(` = unary_op("\\left( ", " \\right)"),
  paste = paste,
  
  # Other math functions
  sqrt = unary_op("\\sqrt{", "}"),
  sin =  unary_op("\\sin(", ")"),
  log =  unary_op("\\log(", ")"),
  abs =  unary_op("\\left| ", "\\right| "),
  frac = function(a, b) {
    paste0("\\frac{", a, "}{", b, "}")
  },
  
  # Labelling
  hat =   unary_op("\\hat{", "}"),
  tilde = unary_op("\\tilde{", "}")
)
```

We again modify `latex_env()` to include this environment. It should be the last environment R looks for names in: in other words, `sin(sin)` should work.


```r
latex_env <- function(expr) {
  # Known functions
  f_env

  # Default symbols
  names <- all_names(expr)
  symbol_env <- as_env(set_names(names), parent = f_env)

  # Known symbols
  greek_env <- env_clone(greek_env, parent = symbol_env)
}

to_math(sin(x + pi))
#> <LATEX> \sin(x + \pi)
to_math(log(x_i ^ 2))
#> <LATEX> \log(x_i^2)
to_math(sin(sin))
#> <LATEX> \sin(sin)
```

### Unknown functions

Finally, we'll add a default for functions that we don't yet know about. Like the unknown names, we can't know in advance what these will be, so we again use a little metaprogramming to figure them out:


```r
all_calls_rec <- function(x) {
  switch_expr(x, 
    constant = ,
    symbol =   character(),
    call = {
      fname <- as.character(x[[1]])
      children <- flat_map_chr(as.list(x[-1]), all_calls)
      c(fname, children)
    },
    pairlist = flat_map_chr(as.list(x[1]), all_calls)
  )
}
all_calls <- function(x) {
  unique(all_calls_rec(x))
}

all_calls(expr(f(g + b, c, d(a))))
#> [1] "f" "+" "d"
```

And we need a closure that will generate the functions for each unknown call.


```r
unknown_op <- function(op) {
  new_function(
    exprs(... = ),
    expr({
      contents <- paste(..., collapse = ", ")
      paste0(!!paste0("\\mathrm{", op, "}("), contents, ")")
    })
  )
}
unknown_op("foo")
#> function (...) 
#> {
#>     contents <- paste(..., collapse = ", ")
#>     paste0("\\mathrm{foo}(", contents, ")")
#> }
#> <environment: 0x7fd0df367e28>
```

And again we update `latex_env()`:


```r
latex_env <- function(expr) {
  calls <- all_calls(expr)
  call_list <- map(set_names(calls), unknown_op)
  call_env <- as_environment(call_list)

  # Known functions
  f_env <- env_clone(f_env, call_env)

  # Default symbols
  names <- all_names(expr)
  symbol_env <- as_env(set_names(names), parent = f_env)

  # Known symbols
  greek_env <- env_clone(greek_env, parent = symbol_env)
}

to_math(f(a * b))
#> <LATEX> \mathrm{f}(a * b)
```

### Exercises

1.  Add escaping. The special symbols that should be escaped by adding a backslash
    in front of them are `\`, `$`, and `%`. Just as with HTML, you'll need to 
    make sure you don't end up double-escaping. So you'll need to create a small 
    S3 class and then use that in function operators. That will also allow you 
    to embed arbitrary LaTeX if needed.

1.  Complete the DSL to support all the functions that `plotmath` supports.
