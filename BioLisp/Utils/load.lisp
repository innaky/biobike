;;; -*- mode: Lisp; Syntax: Common-Lisp; Package: user; -*-

(in-package :cl-user)

;;; +=========================================================================+
;;; | Copyright (c) 2002-2005 JP Massar, Jeff Shrager, Mike Travers           |
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

(defparameter *weblistener-utils-files*
  '(
    "package"
    "string-utils"
    "macro-utils"
    "list-utils"
    "sequence-utils"
    "hash-utils"
    "filepath-utils"
    "symbol-utils"
    "array-utils"
    "sfarray-utils"
    "math-utils"
    "misc-utils"
    "clos-utils"
    "shell-utils"
    "html-utils"
    "circseg-utils"
    "ref"
    "iterators"
    "subranges"
    "garrays"
    "garray-tools"
    "edit-distance"
    "infix"
    ))

;; Make it so the utilities package can be loaded independently.

(let ((actual-load-path nil))
  (handler-case
      ;; this will error if no logical host named 'websrc' is defined or
      ;; translate-simple-lp isn't defined -- the error will be caught below.
      (setq actual-load-path (translate-simple-lp "websrc:Utils;"))
    ;; Catch the error and try to load from the current directory.
    (error
     ()
     (format t "~%;; Warning: No logical host WEBSRC exists!")
     (format t "~%;; Loading from current directory.")
     (if *load-pathname*
         (setq actual-load-path 
               (namestring (dirpath-from-path *load-pathname*)))
       (error "No logical host named WEBSRC and *LOAD-PATHNAME* is NIL!")
       )))
  (load-system* actual-load-path *weblistener-utils-files*)
  )

(when (fboundp 'provides) (funcall 'provides :Utils))
