;;;; This file is part of hasher
;;;; Copyright 2017-2018 Guillaume LE VAILLANT
;;;; Distributed under the GNU GPL v3 or later.
;;;; See the file LICENSE for terms of use and distribution.


(cl:in-package :asdf-user)

;; Redefine 'program-op' to actvate compression
#+(and sbcl sb-core-compression)
(defmethod perform ((o program-op) (c system))
  (uiop:dump-image (output-file o c) :executable t :compression t))

(defsystem "hasher"
  :version "1.0"
  :author "Guillaume LE VAILLANT"
  :maintainer "Guillaume LE VAILLANT"
  :description "Tool to hash file contents"
  :license "GPL-3"
  :depends-on ("ironclad" "uiop")
  :build-operation program-op
  :build-pathname "hasher"
  :entry-point "hasher:main"
  :components ((:file "hasher")))
