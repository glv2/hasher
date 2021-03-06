;;;; This file is part of hasher
;;;; Copyright 2017-2018 Guillaume LE VAILLANT
;;;; Distributed under the GNU GPL v3 or later.
;;;; See the file LICENSE for terms of use and distribution.


(defpackage :hasher
  (:use :cl)
  (:export #:main))

(in-package :hasher)


(defconstant +buffer-size+ 65536)

(defun sanitize-filename (filename)
  (with-input-from-string (in filename)
    (with-output-to-string (out)
      (do ((c (read-char in nil) (read-char in nil)))
          ((null c))
        (when (member c '(#\[ #\] #\*))
          (write-char #\\ out))
        (write-char c out)))))

(defun print-usage ()
  (format *error-output* "~%Usage:~%~%")
  (format *error-output* "  hasher <hash function> <file> [file...]~%")
  (format *error-output* "  hasher -c <hash function> <manifest>~%~%")
  (format *error-output* "Supported hash functions:~%~% ")
  (let ((line-length 1)
        (max-line-length 80))
    (dolist (digest (ironclad:list-all-digests))
      (let ((digest-length (length (symbol-name digest))))
        (incf line-length (1+ digest-length))
        (when (> line-length max-line-length)
          (format *error-output* "~% ")
          (setf line-length (+ 2 digest-length)))
        (format *error-output* " ~(~a~)" digest)))
    (format *error-output* "~%~%"))
  (format *error-output* "Some hash functions can take parameters:~%~%")
  (format *error-output* "  hasher \"shake128 output-length 13\" file...~%")
  (format *error-output* "  hasher \"shake256 output-length 49\" file...~%")
  (format *error-output* "  hasher \"tree-hash digest blake2 block-length 512\" file...~%~%"))

(defun hash-files (digest-name digest-parameters filenames)
  (let* ((digester (apply #'ironclad:make-digest digest-name digest-parameters))
         (buffer (make-array +buffer-size+ :element-type '(unsigned-byte 8)))
         (digest (make-array (ironclad:digest-length digester) :element-type '(unsigned-byte 8))))
    (dolist (filename filenames t)
      (let ((pathspec (uiop:file-exists-p (sanitize-filename filename))))
        (if pathspec
            (progn
              (ironclad:digest-file digester pathspec :buffer buffer :digest digest)
              (reinitialize-instance digester)
              (format t "~a  ~a~%" (ironclad:byte-array-to-hex-string digest) filename))
            (format *error-output* "hasher: '~a' is not a file~%" filename))))))

(defun check-files (digest-name digest-parameters filename)
  (let* ((digester (apply #'ironclad:make-digest digest-name digest-parameters))
         (buffer (make-array +buffer-size+ :element-type '(unsigned-byte 8)))
         (digest-length (ironclad:digest-length digester))
         (digest (make-array digest-length :element-type '(unsigned-byte 8))))
    (with-open-file (manifest filename)
      (do ((line (read-line manifest nil nil) (read-line manifest nil nil)))
          ((null line) t)
        (unless (> (length line) (+ 2 (* 2 digest-length)))
          (error "wrong line format: ~a" line))
        (let* ((hash (subseq line 0 (* 2 digest-length)))
               (filename (subseq line (+ 2 (* 2 digest-length))))
               (pathspec (uiop:file-exists-p (sanitize-filename filename))))
          (if pathspec
              (progn
                (ironclad:digest-file digester pathspec :buffer buffer :digest digest)
                (reinitialize-instance digester)
                (if (string-equal (ironclad:byte-array-to-hex-string digest) hash)
                    (format t "~a: OK~%" filename)
                    (format t "~a: FAILED~%" filename)))
              (format t "~a: Not found~%" filename)))))))

(defun main (&optional (args (uiop:command-line-arguments)))
  (let* ((check-p (and args (string= (first args) "-c")))
         (args (if check-p (rest args) args)))
    (if (< (length args) 2)
        (print-usage)
        (handler-case
            (let* ((digest-spec (first args))
                   (digest-spec-space (position #\space digest-spec))
                   (digest-spec-name (if digest-spec-space
                                         (subseq digest-spec 0 digest-spec-space)
                                         digest-spec))
                   (digest-name (intern (string-upcase digest-spec-name) :keyword))
                   (digest-parameters (when digest-spec-space
                                        (let ((s (subseq digest-spec digest-spec-space)))
                                          (loop for (x i) = (multiple-value-list
                                                             (read-from-string s nil :eof))
                                                  then (multiple-value-list
                                                        (read-from-string s nil :eof :start i))
                                                until (eql x :eof)
                                                collect (if (symbolp x)
                                                            (intern (string-upcase x) :keyword)
                                                            x))))))
              (if check-p
                  (check-files digest-name digest-parameters (second args))
                  (hash-files digest-name digest-parameters (rest args))))
          (t (err)
            (format *error-output* "hasher: ~a~%" err))))))
