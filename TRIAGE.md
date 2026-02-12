# TECO Implementation Triage Report
*Generated from TECO-11.REF analysis - February 2026*

## Executive Summary

This document catalogs the features documented in TECO-11.REF and identifies which are implemented versus missing in the current TECO.PAS implementation.

**Overall Status:**
- ✅ **Implemented**: ~50 commands (62%)
- ❌ **Missing**: ~30 commands (38%)
- 🔧 **Priority**: File operations, Search variants, Stack operations

---

## 1. File Specification Commands

### ✅ Implemented (7/11)
- **ER** - Specify input file ✓
- **EW** - Create output file ✓
- **EB** - Edit file (input + output) ✓
- **EC** - Close and rename output ✓
- **EX** - Close and exit TECO ✓
- **EQ** - Query Q-register (non-standard) ✓
- **E!** - Execute shell command ✓

### ❌ Missing (4/11)
- **EF** - Close output file explicitly (deletes old, renames temp)
- **EK** - Purge temporary output file (undo EB)
- **EI** - Indirect command file (read commands from file)
- **ED** - Edit flags (behavior control, multiple sub-features)
  - ED&1: Append stops at formfeed
  - ED&2: Case sensitive search
  - ED&4: Caret processing in search
  - ED&8: No echo mode
  - ED&16: Search doesn't reposition on failure
  - ED&32: EB creates backup with tilde suffix

**Impact**: Medium-High. EI is needed for batch processing, ED controls important behaviors.

---

## 2. Page Manipulation Commands

### ✅ Implemented (5/5)
- **A** - Append next page ✓
- **Y** - Delete buffer then append ✓
- **nPW** - Write buffer n times ✓
- **m,nPW** - Write character range ✓
- **nP** - Write, append FF, then Y ✓

**Status**: Complete ✅

---

## 3. Buffer Pointer Commands

### ✅ Implemented (4/4)
- **nJ** - Jump to position ✓
- **nC** - Advance characters ✓
- **nR** - Move backward ✓
- **nL** - Line oriented movement ✓

**Status**: Complete ✅

---

## 4. Text Typeout Commands

### ✅ Implemented (4/4)
- **nT** - Line/character typeout ✓
- **nV** - View around current line ✓
- **n^T** - Type ASCII character ✓
- **^A** - Output literal text ✓

**Status**: Complete ✅

---

## 5. Text Deletion/Insertion Commands

### ✅ Implemented (7/7)
- **nD** - Delete characters ✓
- **nK** - Line oriented deletion ✓
- **m,nK** - Delete range ✓
- **HK** - Delete entire buffer ✓
- **Is** - Insert string ✓
- **nI$** - Insert ASCII character ✓
- **n\\** - Insert number representation ✓

### ❌ Missing (1/8)
- **FR** - Replace (partially implemented, but not fully per spec)

**Status**: Nearly complete, FR needs verification

---

## 6. Search Commands

### ✅ Implemented (2/7)
- **nSs** - Basic search ✓
- **nNs** - Search with P commands ✓

### ❌ Missing (5/7)
- **m,nSs** - Bounded search (with limit)
- **nFBs** - Line oriented bounded search
- **n_s** - Search with Y commands
- **nFSss** - Search and replace combined
- **nFNss** - Search with pages and replace
- **nFCss** - Bounded search and replace
- **m,nFCss** - Character bounded search/replace

### 🔧 Partially Missing
- **::Ss** - Compare command (needs verification)
- **Colon-modified searches** - Should return -1/0 instead of errors

**Impact**: High. Many search variants completely missing, colon modifiers not working.

---

## 7. Search String Functions

### ✅ Implemented (9/12)
- **^** - Control character construct ✓
- **^Q** - Literal next character ✓
- **^EQ** - Insert Q-register in search ✓
- **^\\** - Toggle case matching ✓
- **^X** - Match any character ✓
- **^S** - Match non-alphanumeric ✓
- **^N** - Match NOT character ✓
- **^EA** - Match alphabetic ✓
- **^ED** - Match digit ✓
- **^ER** - Match alphanumeric ✓
- **^E[...]** - Character class ✓

### ❌ Missing (3/12)
- **^ES** - Match spaces/tabs string
- **^EL** - Match line terminators (LF/VT/FF)
- **^EC** - Match radix-50 character
- **^EX** - Same as ^X (may be implemented)

**Impact**: Medium. Missing pattern matchers limit search capability.

---

## 8. Q-Register Loading Commands

### ✅ Implemented (8/11)
- **^Uqs** - Insert string into Q-register ✓
- **:^Uqs** - Append string to Q-register ✓
- **n^Uq$** - Insert ASCII character ✓
- **n:^Uq$** - Append ASCII character ✓
- **nXq** - Extract text to Q-register ✓
- **n:Xq** - Append text to Q-register ✓
- **m,nXq** - Extract range to Q-register ✓
- **nUq** - Store numeric value ✓

### ❌ Missing (4/11)
- **m,nUq** - Store two values (equivalent to nUqm)
- **n%q** - Add to numeric Q-register (returns new value)
- **]q** - Pop from Q-register stack
- **:]q** - Pop with success flag

**Impact**: Medium. Stack operations (%,[,]) essential for advanced macros.

---

## 9. Q-Register Retrieval Commands

### ✅ Implemented (4/6)
- **Gq** - Copy Q-register to buffer ✓
- **:Gq** - Print Q-register ✓
- **Qq** - Get numeric value ✓
- **Mq** - Execute Q-register macro ✓

### ❌ Missing (2/6)
- **nQq** - Get ASCII value of nth character (-1 if out of range)
- **[q** - Push Q-register to stack

**Impact**: Medium. Stack push/pop needed for nested macros.

---

## 10. Branching Commands

### ✅ Implemented (10/13)
- **n<** - Loop start ✓
- **>** - Loop end ✓
- **n;** - Conditional loop exit ✓
- **F>** - Branch to loop end ✓
- **F'** - Branch to conditional end ✓
- **F|** - Branch to else clause ✓
- **^[$** - Exit macro level ✓
- **n"X** - Conditional execution ✓
- **!tag!** - Label (parsed as comment) ✓

### ❌ Missing (3/13)
- **F<** - Branch to loop beginning
- **O** - Branch to label (goto)
- Label branching functionality

**Impact**: High. O command (goto) is documented but not working.

---

## 11. Conditional Criterions

### ✅ Implemented (13/13)
- **A** - Alphabetic ✓
- **C** - Radix-50 ✓
- **D** - Digit ✓
- **E** - Equal to zero ✓
- **F** - False (zero) ✓
- **G** - Greater than zero ✓
- **L** - Less than zero ✓
- **N** - Not equal to zero ✓
- **R** - Alphanumeric ✓
- **S** - Successful (negative) ✓
- **T** - True (negative) ✓
- **U** - Unsuccessful (zero) ✓

**Status**: Complete ✅

---

## 12. Numeric Quantities

### ✅ Implemented (7/11)
- **B** - Beginning of buffer (0) ✓
- **Z** - Length of buffer ✓
- **.** - Current position ✓
- **H** - Whole buffer (B,Z) ✓
- **nA** - ASCII value at position ✓
- **Mq** - Macro return value ✓

### ❌ Missing (4/11)
- **:Qq** - Number of characters in Q-register text
- **\\** - Parse number at pointer (with radix support)
- **^E** - Formfeed termination flag (-1 if FF, 0 otherwise)
- **^F** - Process ID
- **^N** - EOF flag (-1 at EOF, 0 otherwise)

**Impact**: Medium. Missing flags limit conditional logic.

---

## 13. Immediate Action Aids

### ✅ Implemented (1/4)
- **linefeed** - Execute "1lt" ✓

### ❌ Missing (3/4)
- ***q** - Save previous command in Q-register
- **?** - Print command up to error
- **BACKSPACE** - Execute "-1lt"

**Impact**: Low. Convenience features.

---

## 14. Immediate Mode Commands

### ✅ Implemented (1/7)
- **$$** - Start command execution ✓

### ❌ Missing (6/7)
- **Backspace** - Delete previous character
- **^U** - Delete current line
- **^G^G** - Delete entire command
- **^G<space>** - Retype command line
- **^G*** - Retype entire command
- **^C** - Delete entire command string

**Impact**: Medium. Command editing features missing.

---

## 15. Execution Mode Commands

### ❌ Missing (4/4)
- **^O** - Toggle printout on/off
- **^S** - Stop printout
- **^Q** - Resume printout
- **^C** - Abort execution (XAB error)

**Impact**: Low. Output control features.

---

## 16. Colon Modifiers

### ❌ Missing (Multiple Commands)
Commands that should support colon prefix to return success (-1) or failure (0):
- **:ER, :EW, :EB, :EI, :E!** - File operations
- **:Ss, :FBs, :Ns, :_s** - Search operations
- **:]q** - Pop operation

**Impact**: High. Error handling depends on these return values.

---

## Priority Ranking

### 🔴 Critical (Blocks Common Use Cases)
1. **O** command - Goto label (documented but broken)
2. **Colon modifiers** - Error handling in scripts
3. **EI** - Indirect command files (batch processing)
4. **ED** flags - Behavior control

### 🟡 High Priority (Limits Functionality)
5. **FB, FS, FN, FC** - Advanced search commands
6. **%, [, ]** - Q-register stack operations
7. **_** - Search with Y commands
8. **F<** - Loop restart
9. **:Qq** - Q-register length query

### 🟢 Medium Priority (Nice to Have)
10. **EF, EK** - File management
11. **^E, ^F, ^N** - System flags
12. **\\** - Radix parsing
13. **^ES, ^EL, ^EC** - Search patterns
14. **nQq** - Q-register character access

### 🔵 Low Priority (Convenience)
15. Immediate mode editing (^U, ^G, etc.)
16. Execution mode controls (^O, ^S, ^Q)
17. ***q, ?** - Command history features

---

## Testing Recommendations

Each missing feature should have:
1. Test case from TECO-11.REF examples
2. Expected vs actual behavior documentation
3. Verification that related features still work

## Next Steps

1. ✅ Document all missing features (this file)
2. ⬜ Create test suite for implemented features
3. ⬜ Prioritize implementation backlog
4. ⬜ Fix critical gaps (O command, colon modifiers)
5. ⬜ Implement high-priority missing features
6. ⬜ Update TECO.DOC to reflect actual implementation

---

*End of Triage Report*
