;;; -*- Package: aframes; mode: lisp; base: 10; Syntax: Common-Lisp; -*-

(in-package :aframes)

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

;;; Author:  JP Massar, Mike Travers.


(defslot #$sys.putDemons :set-valued? t)
(defslot #$sys.getter)
(defslot #$sys.computedSlot)
(defslot #$sys.inverse)
(defslot #$sys.Inheritsthrough)
(defslot #$sys.IsAnInstanceOf)
(defslot #$sys.InstancesOf)
(defslot #$sys.HTMLGenerator)

(def-transitive-slot #$sys.allIsA #$sys.isA)
(def-transitive-slot #$sys.allSubclasses #$sys.subclasses)
(def-transitive-slot #$sys.allParts #$sys.Parts)
(def-transitive-slot #$sys.allPartOf #$sys.partOf)


(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun flag->system-frame (flag)
    (frame-fnamed (one-string "sys." (string-downcase flag)) t)))
                          

(defmacro flagslots (type)
  `(progn 
     ,@(loop for flag in (get type :flags) collect
             `(def-always-computed-slot 
                  (,(flag->system-frame flag)
                   frame slot)
                slot
                (frame-flag-enabled? frame ,flag)
                ))))

(flagslots :frame)
(flagslots :slot)

(defparameter *system-flag-frames* (make-hash-table :test 'eq))

(loop for flag in (append (get :frame :flags) (get :slot :flags)) do
      (setf (gethash (flag->system-frame flag) *system-flag-frames*) t))


                  


