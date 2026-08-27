+++
title = "Data Structures Design in Rust"
date = 2026-08-27
description = "Here I share things that I learned about creating Rust data structures, choosing references vs. values, and ownership semantics."

[taxonomies]
tags = ["rust"]
categories = ["Rust"]
+++

Thoughts and ideas brainstorming:

- tutorials for beginners tend to suggest using owned data types (e.g. String)
  and `.clone()`-ing liberally
- even seasoned Rust developers recommend avoiding structs with generic lifetime
  parameters, if possible
- But, always owning and cloning heap-allocated values is both inefficient and
  even not always needed by a particular algorithm that uses such a data
  structure
- (?) Rust is different from garbage-collected languages not in terms of memory
  management but also in terms of thinking: it makes a developer always think
  where (or by whom) a value is allocated and who (or what piece of data) owns
  it
- (TODO: paste links) Recently, I've been working on an interpreter for the Lox
  educational programming language following the famous book "Crafting
  Interpreters" by Robert Nystrom with the help of the great CodeCrafters
  platform. This exercise has given me a lot of practical experience designing
  Rust data structures, because you need to scan tokens from the source file,
  build the parse tree, store the variables' values in some kind of environment,
  and so on. Even more peculiar detail is that the initial code for the
  interpreter is written in Java. This makes you constantly muscle your brain to
  do the conversion between a garbage-collected design (thinking about "what"
  your data contains) and the Rust's one ("how" your data is stored).
- I've found out one mental model that helps me decide whether I should create
  an owning or a referring data structure. I hope that it may be useful for you
  as well.
- Data structures in Rust are tightly related to
  - the algorithms that use or build them
  - the lifetime (surprisingly) of the source data and the derived data that is
    built from it
- Think in arenas (String with the Lox source read from disk lives at least
  until the parse tree is built, so Expr holds a Literal with a Str(&'a str)
  variant)
- Produced vs consumed data structures (Expr with Box-ed Expr children vs Token
  with &'a str)
  - Produced data structures own their values by default (Value, because of
    concatenation, arithmetic operations, etc.)
  - Consumed data structures hold references by default (Expr). "If I don't
    build the data, don't allocate it, the reference is enough".
- If you need 2 (or more) data structures to own "the same" data, you have
  several options (example with Environment and Exprs cloning):
  - Use a shared arena (the third, owning data structure with the longest
    lifetime, and make the former two refer to it)
  - Choose the "source of truth" (the data structure that owns the data and
    whose lifetime is the longest) and place the data where wrapped in an Rc or
    Arc, then use clone() to efficiently share it with the other data structures
