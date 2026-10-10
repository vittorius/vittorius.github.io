+++
title = "Data Structures Design in Rust"
date = 2026-08-27
description = "References, owned values, smart pointers: the not-so-easy-choice"

[taxonomies]
tags = ["rust"]
categories = ["Rust"]
+++

## Structure

- introduction
  - tutorials for beginners tend to suggest using owned data types (e.g. String)
    and `.clone()`-ing liberally
  - even ~~seasoned~~ (experienced) Rust developers recommend to avoid structs
    with generic lifetime parameters, if possible
  - But, always owning and cloning heap-allocated values is both inefficient and
    even not always needed by a particular algorithm that uses such a data
    structure
  - On the other hand, it becomes not so hard to use lifetime-parameterized data
    structures if we develop a) the thinking approach b) a set of patterns to
    apply
  - NOTE: throughout this article, I call structures that own their fields' data
    "owning data structures" (`struct S { field: String }`), the ones that hold
    references "referential data structures"
    (`struct R<'a> { field: &'a str }`).

- case study: an interpreter
  - (TODO: paste links) Recently, I've been working on an interpreter for the
    Lox educational programming language following the famous book "Crafting
    Interpreters" by Robert Nystrom with the help of the great CodeCrafters
    platform. This exercise has given me a lot of practical experience designing
    Rust data structures, because you need to scan tokens from the source file,
    build the parse tree, store the variables' values in some kind of
    environment, and so on. Even more peculiar detail is that the initial code
    for the interpreter is written in Java. This makes you constantly muscle
    your brain to do the conversion between a garbage-collected design (thinking
    about "what" your data contains) and the Rust's one ("how" your data is
    stored).
  - During this exercise, I've was in a search of the mental model that will
    help me decide whether I should create an owning or a referring data
    structure. I think I've found one and it proved itself while working on a
    couple of next projects. I hope that it may be useful for you as well.
- it all starts with the algorithm
  - (?) Rust is different from garbage-collected languages not in terms of
    memory management but also in terms of thinking: it makes a developer always
    think where (or by whom) a value is allocated and who (or what piece of
    data) owns it
  - algorithm dictates the flow of your data:
    - where it comes from or, more precisely, how it's allocated, where and when
      it flows (is moved?)
    - what produces it and what consumes it
    - for how the derived data lives compared to the source data it was produced
      from
  - let's talk about all of these {categories? ideas? what?} in detail

- Produced vs consumed data structures (Expr with Box-ed Expr children vs Token
  with &'a str)
  - Produced data structures own their values by default (Value, because of
    concatenation, arithmetic operations, etc.)
  - Consumed data structures hold references by default (Expr). "If I don't
    build the data, don't allocate it, the reference is enough".

- Thinking in (relative) data lifetimes
  - if you have a derived data structure that will surely live shorter than its
    source data, then it's a very good candidate for a referential data
    structure. (example with the Resolver)
  - an interesting case: one-pass interpreter (everything below the source
    String allocation is within its lifetime so every data structure down the
    line, including the Environment and event Tokens is made referential) vs
    REPL (when you understand that the environment must outlive each new source
    line interpreted after every Enter hit)
  - advanced approach: arena or a dedicated string interner. "Outsource" the
    ownership to an extracted data structure that will own all the Strings (or
    your use-case data structures that have to be allocated massively during the
    program execution) that lives throughout the entire program run time. Make
    all other data structures refer to the data pieces stored in such a storage.
    But, it won't a magical wand that will always help :) See the next section
    below.

- The rabbit hole
  - Things start to get difficult when you need to pass down a referential data
    structure down below a long call graph, for instance, in a recursive
    algorithm like the recursive descent parser in our interpreter. (present the
    example with Env<'a> param sending down the callstack). Lifetime annotations
    and "dependencies" on a concrete lifetime pollutes all the function
    signatures down the callstack.
  - This brings even more issues if (for instance, because of a particular
    algorithm, like the Visitor pattern implementation (TODO: reference to a
    concrete file on Github)), you have to make method receivers depend on that
    concrete lifetime of the referential data structure in the argument
    (`&'a self` or `&'a mut self`). `&'a mut self` is the true archenemy of a
    Rustacean. If you have a method with the `&mut self` receiver - say goodbye
    to even calling other mutator methods inside it! You can have only one mut
    reference at a time, remember? In the same fashion, Rust will relieve you
    from loops that refer to `self` - because every loop iteration is considered
    a separate mutable borrow.
  - If you have to pass a mutable reference to such a referential struct down
    the call graph, you'll find out (the hard way) that `mut` references are not
    covariant (compiler does not extend or shrink their lifetimes) and you
    should expect "lifetime may not live long enough" errors in much more cases

- TODO Self-referential data structures
  - unfortunately, lifetimes in Rust are pretty restricted and work well in a
    limited set of case. Also, they don't allow to define self-referential data
    structures.

- TODO: sort out the brainstorming from the UpNote
  https://getupnote.com/share/notes/frcg7yksiTVMYE3OebBC3xrY4Vi1/01a125b8-2442-709f-99fb-10daec957d9a
