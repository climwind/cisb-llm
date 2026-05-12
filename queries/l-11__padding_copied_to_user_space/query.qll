import cpp

/**
 * Holds if the target architecture is sparc64, as indicated by
 * the presence of both __sparc__ and __arch64__ macros.
 */
predicate isSparc64() {
  none() /* Phase 2: restrict to sparc64 */
}

/**
 * A struct type that has implicit padding bytes, i.e., its total size
 * is not equal to the sum of the sizes of its fields.
 */
class StructWithPadding extends Class {
  StructWithPadding() {
    exists(int size, int sumFieldSizes |
      this.getSize() = size and
      sumFieldSizes = sum(Field f | f.getDeclaringType() = this | f.getType().getSize()) and
      size != sumFieldSizes
    )
  }
}

/**
 * Holds if `assign` is an assignment that writes to a field `f` of the struct variable `v`.
 */
predicate fieldAssignment(AssignExpr assign, Variable v, Field f) {
  exists(FieldAccess ma |
    ma = assign.getLValue() and
    ma.getTarget() = f and
    ma.getQualifier() = any(VariableAccess va | va.getTarget() = v)
  )
}

/**
 * Holds if the struct value of `v` is used as a source (value or address) in a copy operation
 * that sends data to user space. This includes memcpy, copy_to_user, aggregate assignment,
 * and their builtin variants.
 */
predicate structExposedToUser(Variable v) {
  exists(FunctionCall call |
    call.getTarget().hasName(["memcpy", "__builtin_memcpy", "copy_to_user", "__copy_to_user"]) and
    exists(Expr arg | arg = call.getArgument(1) | arg.(AddressOfExpr).getOperand().(VariableAccess).getTarget() = v)
  ) or
  exists(AssignExpr assign |
    assign.getLValue().getType().(PointerType).getBaseType() = v.getType() and
    assign.getRValue().(VariableAccess).getTarget() = v
  )
}

/**
 * A struct variable that is only written to via individual field assignments
 * (no aggregate initialization or memset) before being exposed to user space.
 */
predicate structWithUninitializedPadding(Variable v) {
  exists(StructWithPadding stp | v.getType() = stp) and
  exists(AssignExpr assn | fieldAssignment(assn, v, _)) and
  not exists(AssignExpr init | init.getLValue().(VariableAccess).getTarget() = v) and // no aggregate assignment as initialization? This is approximate.
  not exists(FunctionCall memset |
    memset.getTarget().hasName(["memset", "__builtin_memset", "explicit_bzero"]) and
    memset.getArgument(0).(AddressOfExpr).getOperand().(VariableAccess).getTarget() = v
  ) and
  structExposedToUser(v)
}
