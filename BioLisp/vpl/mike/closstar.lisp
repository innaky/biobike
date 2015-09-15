;;;; -*- mode: Lisp; Syntax: Common-Lisp; Package: clos* ; -*-

(defpackage :clos*
  (:use #+genera clos #+MCL ccl common-lisp)
  (:export "DEFCLASS*" "DEFMETHOD*"))

(in-package :clos*)

#| ######################################################################

 Alternate syntax for CLOS

Copyright � 1994-97 Michael Travers 

Permission is given to use and modify this code
as long as the copyright notice is preserved.

Send questions, comments, and fixes to mt@alum.mit.edu

-------------------------------------------------------------------------

This package provides two defining forms, defclass* and defmethod*, that 
work like the ordinary CLOS forms but provide some of the convenience 
features of the Flavors system.  Initially developed to run Flavors code
under CLOS without conversion, CLOS* is also useful for rapid prototyping
since it allows class and method definitions to expressed more succinctly
than the default CLOS syntax.

defclass* uses a more convienient defflavor-like syntax for expressing
slot options.  

Example:
(defclass* pixmap-dialog-item (dialog-item)
  (pixmap
   (dispose nil))                       ; slot with an initial value of NIL
  :initable-instance-variables)         ; define init keywords for all slots

defmethod* makes the slots of the first argument available as symbols (that
is, it does an implicit (with-slots <all-slots> <1st-arg> ...)). Purists
will disapprove. WITH-SLOTS generates calls to SLOT-VALUE, which is
generally slower than using accessors. 


WARNING: defmethod* requires that the class be fully defined at compile
time. Compiling a defclass* form to a file will also define the class in
Lisp, but compiling a normal defclass won't. So, using defclass and
defmethod* together may break depending on your compilation and loading
scheme.



History:
Based on my old Artificial Flavors package
PCL version 31 March 90
CLOS version 13 August 90

6/13/97 7:52pm   DEFCLASS* can deal with DEFCLASS style iv-defs

###################################################################### |#


(defmacro defclass* (name components ivs &rest options)
  (let ((reader-slots nil)
        (writer-slots nil)
        (init-slots nil)
        (bare-ivs nil)
        (class-options nil)
        (keyword-package (find-package 'keyword)))
    (dolist (option options)
      (let ((option-name (if (listp option) (car option) option))
            (option-value (if (listp option) (cdr option) nil)))
        (flet ((spec-or-all-ivs (spec)
                 (or spec
                     (mapcar #'(lambda (iv) (if (listp iv) (car iv) iv)) ivs))))
          (case option-name
            (:writable-instance-variables
             (setq writer-slots (spec-or-all-ivs option-value))
             (setq reader-slots (nunion reader-slots (spec-or-all-ivs option-value))))
            (:readable-instance-variables
             (setq reader-slots (nunion reader-slots (spec-or-all-ivs option-value))))
            (:initable-instance-variables
             (setq init-slots (spec-or-all-ivs option-value)))
            (t (push option class-options))))))
    (setq reader-slots (set-difference reader-slots writer-slots))
    (flet ((process-iv (iv-form)
             (let ((iv (if (listp iv-form) (car iv-form) iv-form)))
               (push iv bare-ivs)
               `(,iv
                 ,@(if (listp iv-form)
                     (if (= 2 (length iv-form))
                       `(:initform ,(cadr iv-form))
                       (cdr iv-form)))
                 ,@(if (member iv init-slots)
                     `(:initarg ,(intern (symbol-name iv) keyword-package)))
                 ,@(if (member iv reader-slots)
                     `(:reader ,(symbol-conc name "-" iv)))
                 ,@(if (member iv writer-slots)
                     `(:accessor ,(symbol-conc name "-" iv)))))))
      (let ((defclass-form `(defclass ,name ,components ,(mapcar #'process-iv ivs) ,@class-options)))
        `(progn
           (eval-when (:compile-toplevel)
             ,defclass-form)
           ,defclass-form))
        )))

(defun symbol-conc (&rest components)
  (intern (apply #'concatenate 'string (mapcar #'string components))))

;;; If you use defmethod* but don't make use of any of the defined slots, you will get a warning
;;; that a temporary variable (generated by with-slots) is unused.  I'm leaving this
;;; in to discourage the use of defmethod* unless necessary.

(defmacro defmethod* (&rest args &environment env)
  (declare (ignorable env))
  (multiple-value-bind (name qualifiers lambda-list body)
      (parse-defmethod args)
    (multiple-value-bind (decls main-body)
        (split-off-declarations body)
      (let* ((class (cadar lambda-list)) 
             (slots (slots-for-class class)))
        (unless slots
          (warn "No slots for ~A, may be some finalization problems" class))
        `(defmethod ,name ,@qualifiers ,lambda-list
                    ,@decls
           (with-slots ,slots ,(caar lambda-list)
             ;; Eliminate compiler warnings
             #+:CCL (declare (ignore-if-unused ,@slots)) 
             ,@main-body))))))

;; not sure where this worked, but it doesn't in ACL6.2
;; nor in Lispworks
#-(OR :ALLEGRO :LISPWORKS)
(setf (arglist 'defmethod*)
      '(name |{method-qualifier}*|
        specialized-lambda-list
        &body body))

(defun parse-defmethod (form)
  (let ((name (first form))
        (qualifiers nil))
    (do ((rest (cdr form) (cdr rest)))
        ((not (symbolp (car rest)))
         (values name (nreverse qualifiers) (car rest) (cdr rest)))
      (push (car rest) qualifiers))))

#+MCL
(defun slots-for-class (class-name)
  (let ((class (find-class class-name)))
    (nconc (mapcar #'slot-definition-name
                   (class-instance-slots class))
           (mapcar #'slot-definition-name
                   (class-class-slots class)))))

;;; For ACL7 this works, for certain earlier versions use cg:name 
;;; instead of mop:slot-definition-name
#+ALLEGRO
(defun slots-for-class (class-name)
  (let ((class (find-class class-name)))
    (mapcar #'mop:slot-definition-name (clos:compute-slots class))))

#+:LISPWORKS
(defun slots-for-class (class-name)
  (let ((class (find-class class-name)))
    (mapcar #'hcl:slot-definition-name (clos:compute-slots class))))

(defun split-off-declarations (body)
  (do ((rest body (cdr rest))
       (declarations nil))
      ((null rest)
       (values declarations nil))
    (if (or (stringp (car rest))
            (and (listp (car rest))
                 (eq 'declare (car (car rest)))))
        (push (car rest) declarations)
        (return-from split-off-declarations
          (values (nreverse declarations) rest)))))

#+MCL (add-definition-type 'class "CLASS*")
#+MCL (add-definition-type 'method "METHOD*")

#+not-needed
;; these are exported at the top of the file
(eval-when (:compile-toplevel :load-toplevel :execute)
  (export '(defmethod* defclass*)))

(provide :closstar)
