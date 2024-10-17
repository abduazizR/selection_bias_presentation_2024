// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}



#let article(
  title: none,
  authors: none,
  date: none,
  abstract: none,
  abstract-title: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: "1",
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}

#set table(
  inset: 6pt,
  stroke: none
)
#show: doc => article(
  title: [Chapter 8: Selection bias],
  authors: (
    ( name: [Abdullah Abdelaziz, BPharm, MSc],
      affiliation: [],
      email: [] ),
    ),
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 1,
  doc,
)


== Important disclaimer
<important-disclaimer>
- The term "Selection bias" can refer to different things depending on the discipline

  - Economists’ selection bias (selection on observables) is actually epidemiologists’ confounding bias.

  - Survey statisticians use selection bias term to sample selection from population, which can lead to biased conclusions in descriptive research.

- Epidemiologists excelled in conceptualizing and making the distinction between confounding and selection.

- It’s a good habit to make sure that your collaborators are on the same page regarding terminology to avoid confusions.

= General guidelines
<general-guidelines>
== General guidelines
<general-guidelines-1>
- Causal effects are linked to specific #strong[populations]
- In many epidemiologic studies, you end up analyzing a cohort that’s different from your original cohort
  - Survival analysis: we analyze uncensored individuals (we don’t see the outcome in censored individuals).
  - Case-control studies: we analyze individuals who got the outcome and a sample of patients who did not get the outcome.

== General guidelines
<general-guidelines-2>
- The hope is that the estimate we get in this subset is the same as the one we would’ve had if we did the estimation on the original cohort.
- If this is not the case ➔ Selection bias
- In all the coming DAGs, selection is represented as a variable with a square around it.
- The square here does not mean statistical adjustment. It means that the analysis is done on one stratum of the selection variable.
  - DAGs are not just useful in helping identifying adjustment covariates. They can help in the design as well.

= Types of selection bias
<types-of-selection-bias>
== Selection bias under the null
<selection-bias-under-the-null>
- This type of selection bias can arise regardless of the true treatment effect being null or not.
- Conditioning on a collider (or a descendant of a collider) is necessary for this bias to happen.
- This is the topic of this book and Hernan’s famous paper in 2004 @hernán2004

== Selection bias off the null
<selection-bias-off-the-null>
#block[
#block[
- This type of selection bias #strong[cannot] happen under the null.

- This type of selection bias #strong[can] happen even without conditioning on colliders.

]
#block[
#align(center)[
#box(image("images/paste-1.png"))
]
]
]
- This bias is not covered in the chapter.

= Selection bias in cross-sectional studies
<selection-bias-in-cross-sectional-studies>
== Example 1
<example-1>
#align(center)[
#box(image("images/paste-3.png", width: 403))
]
- $A$ : Treatment

- $Y$ : Fetal malformation

- $C$ : Live birth

  We don’t have $Y$ for dead fetuses, so we essentially #strong[restricting our analysis to] living fetuses.

== Example 1
<example-1-1>
- Our regression will give us this quantity

$ frac(P r [Y = 1 \| A = 1 , C = 0], P r [Y = 1 \| A = 0 , C = 0]) $

- Is this a valid estimate for our estimand?

  $ frac(P r [Y^(a = 1) = 1], P r [Y^(a = 0) = 1]) $

  The answer is no, because we have association transmitted through the path $A arrow.r C arrow.l Y$

== Example 2
<example-2>
#box(image("images/paste-4.png"))

- $A$ : Treatment

- $Y$ : Fetal malformation

- $C$ : Live birth

- $S$: Parental grief

A descendant of a collider is as dangerous as the collider itself.

= Selection bias in cohort studies
<selection-bias-in-cohort-studies>
Including randomized trials

== Example
<example>
#align(center)[
#box(image("images/paste-5.png"))
]
#block[
#set text(size: 0.7em); - $A$ : Antiretroviral treatment

- $Y$: Death

- $L$: Disease severity

- $U$: High level of immunosuppression

- $C$: Loss to follow-up

]
== Example
<example-3>
- Remember, $C$ is not a variable we put in a regression model. It’s a part of how your #strong[analyzed data was formed];.

- In this example, $A$ can show favorable result not because it’s actually effective in reducing mortality, but because it caused sick people to leave the study. Although in reality, $A$ and $Y$ are not associated.

- The previous DAG is an example of selection bias due to #strong[differential loss-to-follow-up] or #strong[informative censoring.]

== Similar DAGs for differential loss-to-follow-up
<similar-dags-for-differential-loss-to-follow-up>
#block[
#block[
#box(image("images/paste-6.png"))

]
#block[
#box(image("images/paste-7.png"))

]
#block[
#box(image("images/paste-8.png"))

]
]
- These DAGs are modified versions of Figure 8.3

  - For instance, in figure 8.4, the association between $A$ and $L$ is represented by mediation while in figure 8.5 presented by a backdoor path $A arrow.l W arrow.r C$ and presented by both in figure 8.6

= Selection bias in case-control studies
<selection-bias-in-case-control-studies>
== DAG
<dag>
#align(center)[
#box(image("images/paste-13.png"))
]
- $E$: Estrogen use

- $D$: CHD

- $F$: Hip fracture

- $C$: Selection into the study

== Matched case-control designs are inherently biased
<matched-case-control-designs-are-inherently-biased>
#box(image("images/paste-14.png"))

== The structural definition of selection bias
<the-structural-definition-of-selection-bias>
#quote(block: true)[
#strong[Selection bias] to refer to all biases that arise from conditioning on a common effect of two variables, one of which is either the treatment or a cause of treatment, and the other is either the outcome or a cause of the outcome.
]

#strong[Selection bias,] similar to confounding bias, is a violation of the exchangeability assumption.

== Common examples of selection bias
<common-examples-of-selection-bias>
- Differential loss to follow-up or informative censoring.

- Missing data bias, or non-response bias.

- Healthy worker bias.

- Self-selection bias or volunteer bias.

- Selection affected by treatment received before study entry aka #strong[prevalent-user bias]

- Immortal-time bias is a mix of selection and misclassification bias.

== Which designs are prone to selection bias?
<which-designs-are-prone-to-selection-bias>
- All of them, even randomized experiments.

- Randomization fixes confounding but not selection.

- Selection bias is more likely to occur with designs that are built on selection by default i.e.~case-control design

  - Friendly advice, whenever you have the full cohort, please don’t conduct a case-control study.

== Which analyses are prone to selection bias?
<which-analyses-are-prone-to-selection-bias>
- Conventional covariate adjustment in treatment-confounder feedback setting.

- Cox regression.

== Selection without bias
<selection-without-bias>
- RCTs are conducted among volunteers willing to enter the experiment. So those volunteers select into the trial.

- However, this is not what we mean here by selection bias.

- Based on our definition, the selection variable should be a #strong[common effect] of the treatment or a cause of the treatment and the outcome or cause of the outcome.

- Since volunteering participation happened #strong[before] treatment assignment, there is no bias.

- The self-selection bias we mentioned earlier is about agreeing to continue in the trial after being treated.

= The distinction between confounding and selection bias
<the-distinction-between-confounding-and-selection-bias>
== Example
<example-4>
#block[
#block[
#block[
#set text(size: 0.7em); - $A$: Physical activity.

- $Y$: Heart disease

- $C$ : Being a firefighter

- $L$: Parental socieconomic status

- $U$: Attraction towards physical activity

]
]
#block[
#align(center)[
#box(image("images/paste-9.png"))
]
]
]
== Advantages of using the structural approach
<advantages-of-using-the-structural-approach>
== 1
It can guide the choice of the analytic method

#align(center)[
#box(image("images/paste-10.png"))
]
== 2
It can help is study design and data collection. #box(image("images/paste-9.png"))

== 3
Selection bias resulting from conditioning on pre-treatment variables (e.g., being a firefighter) could explain why certain variables behave as "confounders" in some studies but not others.

== 4
Causal diagrams enhance communication among investigators and may decrease the occurrence of misunderstandings.

== Important reminder
<important-reminder>
- DAGs ignore the magnitude or direction of selection bias and confounding.
- It is possible that some noncausal paths opened by conditioning on a collider are weak and thus induce little bias.
- It is not an "all or nothing" issue, in practice, it is important to consider the expected direction and magnitude of the bias

== Selection bias in hazard ratios
<selection-bias-in-hazard-ratios>
#block[
#block[
#block[
#set text(size: 0.7em); - $A$: Treatment (protective)

- $Y_1 med upright("and") med Y_2$: Death at time 1 and time 2.

- $U$: Protective Haplotype

]
]
#block[
#align(center)[
#box(image("images/paste-11.png"))
]
]
]
=== Measures of effects
<measures-of-effects>
==== Risk ratio
<risk-ratio>
$ a R R_(A Y_1) = frac(P r [Y_1 = 1 \| A = 1], P r [Y_1 = 1 \| A = 0]) $

$ a R R_(A Y_2) = frac(P r [Y_2 = 1 \| A = 1], P r [Y_2 = 1 \| A = 0]) $

==== Hazard ratio
<hazard-ratio>
$ H R_(A Y_1) = a R R_(A Y_1) = frac(P r [Y_1 = 1 \| A = 1], P r [Y_1 = 1 \| A = 0]) $

$ H R_(A Y_2) = a R R_(A Y_2 \| Y_1 = 0) = frac(P r [Y_2 = 1 \| A = 1 , Y_1 = 0], P r [Y_2 = 1 \| A = 0 , Y_1 = 0]) $

== 
<section-4>
In conclusion, we have two issues:

- The estimand changed.

- Selection bias

= Avoiding selection bias
<avoiding-selection-bias>
== New estimand
<new-estimand>
- Similar to the interaction chapter, we will view selection or censoring as an intervention. If we are able to satisfiy the causal identification assumption with $c$, then this estimand can be estimated using observed data

$ frac(P r [Y^(a = 1 , c = 0) = 1], P r [Y^(a = 0 , c = 0) = 1]) $

- This reads as the effect of $A$ on $Y$ had everyone got $A$ and remained uncensored vs everyone not getting $A$ and remained uncensored.

- Weighting can be a good approach to achieve this (See example).

== References
<references>
#block[
] <refs>



#bibliography("references.bib")

