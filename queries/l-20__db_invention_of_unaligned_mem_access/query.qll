import cpp

/**
 * A variable declaration entry (possibly macro-expanded) that:
 * - has static or global storage duration
 * - has a struct or union type
 * - has a section attribute
 * - does NOT have an explicit alignment attribute
 */
class VariableInSectionWithoutAlignment extends VariableDeclarationEntry {
  VariableInSectionWithoutAlignment() {
    // storage: static or global
    (
      this.getDeclaration().isStatic() or
      this.getDeclaration().isStatic()
    ) and
    // type is struct or union (including typedefs, etc.)
    this.getType().(DerivedType).getBaseType() instanceof Struct and
    // has section attribute
    exists(Attribute a | a = this.getDeclaration().getAnAttribute() | a.getName() = "section") and
    // no aligned attribute
    not exists(Attribute a | a = this.getDeclaration().getAnAttribute() | a.getName() = "aligned")
  }
}
