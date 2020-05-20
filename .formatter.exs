locals_without_parens = [deft: :*, defpt: :*, defmacrot: :*, defmacropt: :*]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
