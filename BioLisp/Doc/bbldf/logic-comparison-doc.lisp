;;; -*- Package: bbi; mode: lisp; base: 10; Syntax: Common-Lisp; -*-

(in-package :bbi)

;;; +=========================================================================+
;;; | Copyright (c) 2002, 2003, 2004 JP Massar, Jeff Shrager, Mike Travers    |
;;; |                                                                         |
;;; | Permission is hereby granted, free of charge, to any person obtaining   |
;;; | a copy of this software and associated documentation files (the         |
;;; | "Software"), to deal in the Software without restriction, including     |
;;; | without limitation the rights to use, copy, modify, merge, publish,     |
;;; | distribute, sublicense, and/or sell copies of the Software, and to      |
;;; | permit persons to whom the Software is furnished to do so, subject to   |
;;; | the following conditions:                                               |
;;; |                                                                         |
;;; | The above copyright notice and this permission notice shall be included |
;;; | in all copies or substantial portions of the Software.                  |
;;; |                                                                         |
;;; | THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,         |
;;; | EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF      |
;;; | MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  |
;;; | IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY    |
;;; | CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,    |
;;; | TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE       |
;;; | SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                  |
;;; +=========================================================================+

;;; Author: JP Massar, Arnaud Taton and Jeff Elhai.

(eval-when (:compile-toplevel :load-toplevel :execute)
  (import '(
            com.biobike.help:document-module
               com.biobike.help:document-function) :bbi))

(DOCUMENT-MODULE flow-logic
  "Functions dealing with program flow and logical choices"
  (:keywords :logic :predicate :true :false)
  (:display-modes :bbl)
  (:submodules logical-comparison
               logical-connectives
               loops-and-conditional-execution
               other-logic-functions)
  #.`(:FUNCTIONS apply-function repeat-function if-false if-true for-each true? 
                 both either raise-error))  

(DOCUMENT-MODULE logical-comparison
  "Properties of genes and proteins"
  (:keywords :compare :greater :less)
  (:display-modes :bbl)
  (:toplevel? nil)
  #.`(:FUNCTIONS true? same all-same all-true any-true all-false any-false > >= = < <= 
          greater-than less-than not))


(DOCUMENT-MODULE logical-connectives
  "Properties of genes and proteins"
  (:keywords :compare :greater :less)
  (:display-modes :bbl)
  (:toplevel? nil)
  #.`(:FUNCTIONS both neither and or)
  (:SEE-ALSO (:module other-logic-functions))
  )


(DOCUMENT-MODULE loops-and-conditional-execution
  "Iteration and control over the flow of logic"
  (:keywords :if :condition :branch :loop :iteration :iterative)
  (:display-modes :bbl)
  (:toplevel? nil)
  #.`(:FUNCTIONS when unless if-false if-true loop for-each apply-function
            Condition Case typecase return return-from when-value-of))

(DOCUMENT-MODULE other-logic-functions
  "Alternate functions that might speed execution"
  (:keywords)
  (:display-modes :bbl)
  (:toplevel? nil)
  #.`(:FUNCTIONS  = < <= > >= and or))




