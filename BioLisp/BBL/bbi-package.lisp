;;;; -*- mode: Lisp; Syntax: Common-Lisp; Package: cl-user; -*-

(in-package :cl-user) 

;;; +=========================================================================+
;;; | Copyright (c) 2005 JP Massar, Jeff Elhai, Mark Slupesky, Peter Seibel   |
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

;;; Author: JP Massar. 

(defpackage :bbi
  (:nicknames :bbl-internals :bbli :biobike-internals)
  (:use :common-lisp :bioutils :utils :frames :webuser :biolisp)
  #+not-needed?
  (:shadowing-import-from :wlisp :defun)
  ;; for arrow notation in brackets
  (:import-from :utils :->)
  (:import-from :com.biobike.help :document-function)
  (:export :define-function :defconversion 
   :remove-conversion :show-defconversions :bbload)
  (:shadow :frame :gene :protein :contiguous-sequence :organism)
  )



