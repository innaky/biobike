;;;; -*- mode: Lisp; Syntax: Common-Lisp; Package: wb; -*-

(in-package :wb)

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

;;; Author: JP Massar. 

;;; Methods for the BIOSEED instance of BioLingua.

(defparameter *instance-string* "BIOSEED")

;;; This file isn't actually loaded.  
;;; Its contents must be moved to the instance's
;;; directory's biodemo-instance-init.lisp file.

(cformatt 
 (one-string
  "If you see this the instance-init file for BioLingua instance " 
  "~A is being loaded")
 *instance-string*)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(cformatt "Defining methods for ~A instance." *instance-string*)

;;; This file can't be loaded by the standard system because the USER:BIOSEED
;;; class only exists when the BIODEMO instance is run.

(defmethod login-header ((app cl-user:bioseed))
  (html
   (:head 
    ((:font :size 6)
     (:center
      (:princ-safe
       (formatn
        "Welcome to ~A" 
        (or *application-instance-pretty-name* 
            "the PhAnToMe BioBike/SEED Server!")))
      :br
      (:princ-safe 
       (s+ 
        "SEED Organisms Edition " (application-version app :mode :short))
       ))))))


(defmethod application-instance-initializations ((app cl-user:bioseed))
  (cformatt "Running ~a instance-specific initializations." (type-of app))
  (ecase user::*frame-system-version* 
    (:old (forward-funcall 'bio::application-instance-initializations-nsf))
    (:sframes 
     (if (null user::*master-list-enabled*)
         (forward-funcall 'bio::application-instance-initializations-sf)
       (forward-funcall 'bio::application-instance-initializations-msf)
       )))
  (cformatt "~a instance-specific initializations complete." (type-of app))
  )

(defun create-seed-organism-selection-operators ()
  (eval (generate-seed-organism-selection-operators))
  #+slower
  (c/l-seed-organism-selection-operators)
  #+slowest
  (funcall
   (compile
    nil
    `(lambda () ,(generate-seed-organism-selection-operators))
    ))
  )

(defun seed-organism-frame-operator (frame) 
  (intern (s+ (#^Fname frame) "-" "OPERATOR") :vpl))
                     
(defun generate-seed-organism-selection-operators ()
  `(progn
     ,@(mapcan
        (lambda (frame)
          `((vpl::defun-opcode ,(seed-organism-frame-operator frame) (sid)
              (declare (ignore sid))
              (vpl::seed-organism-menu-select ,frame)
              )))
        bio::*seed-genome-frames*
        )))

(defun c/l-seed-organism-selection-operators ()
  (let ((forms (generate-seed-organism-selection-operators)))
    (cformatt "Generated ~D organism selection operators..."  (length forms))
    (with-temp-file-in 
        (filepath user::*tmp-directory* :name "seedops" :type "lisp")
      (with-open-file (p filepath :direction :output :if-exists :supersede)
        (pprint '(in-package :vpl) p)
        (terpri p)
        (pprint forms p)
        )
      (cformatt "Created file ~A with organism selection operators" filepath)
      (c/l filepath)
      (cformatt "Loaded organism selection operators file")
      (let ((fasl-file (pathname-of-new-type filepath "fasl")))
        (ignore-errors (delete-file fasl-file))
        (cformatt "Deleting .lisp and .fasl files")
        ))))
        
                               

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(cformatt "Method definitions for ~A complete." *instance-string*)
(cformatt "~A instance-init file loaded." *instance-string*)

