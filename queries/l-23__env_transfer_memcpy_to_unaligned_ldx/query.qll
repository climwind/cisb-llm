import cpp

/**
 * Holds if the struct type `t` lacks explicit alignment attributes
 * (no __packed, no __aligned, and no gcc::packed or gcc::aligned attributes).
 */
predicate structLacksAlignmentAttribute(Struct t) {
  not exists(Attribute a |
    a = t.getDecl().getADeclEntry().getAnAttribute() and
    (a.getName() = "packed" or a.getName() = "aligned" or
     a.getName() = "__packed__" or a.getName() = "__aligned__" or
     a.getName() = "gcc::packed" or a.getName() = "gcc::aligned"))
}

/**
 * A memory access that may be unaligned due to missing struct alignment attributes.
 */
class PotentialUnalignedAccess extends Expr {
  Struct targetStruct;

  PotentialUnalignedAccess() {
    exists(Struct s | structLacksAlignmentAttribute(s) and
      (
        // Struct assignment: both sides have same struct type s
        exists(AssignExpr ae |
          ae.getLValue().getType().stripType() = s and
          ae.getRValue().getType().stripType() = s and
          this = ae
        )
        or
        // memcpy call with size = sizeof(s)
        exists(Call c |
          c.getTarget().getName().matches("%memcpy") and
          c.getArgument(2).getValue().toInt() = s.getSize() and
          (c.getArgument(0).getType().stripType() = s or
           c.getArgument(1).getType().stripType() = s) and
          this = c
        )
        or
        // Pointer dereference (load/store via pointer to s)
        exists(PointerDereferenceExpr pd |
          pd.getOperand().getType().stripType().(PointerType).getBaseType() = s and
          this = pd
        )
        or
        // Array access: p[i] where p is pointer to s
        exists(ArrayExpr ae |
          ae.getArray().getType().stripType().(PointerType).getBaseType() = s and
          this = ae
        )
      ) and
      targetStruct = s
    )
  }

  Struct getStruct() { result = targetStruct }
}

/**
 * Holds if the expression `e` is a potential unaligned access to struct `s`.
 */
predicate isPotentialUnalignedAccess(Expr e, Struct s) {
  e.(PotentialUnalignedAccess).getStruct() = s
}
