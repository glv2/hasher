LISP ?= sbcl
asdf_system := hasher

all:
	${LISP} \
		--load "${asdf_system}.asd" \
		--eval "(asdf:make \"${asdf_system}\")" \
		--eval "(uiop:quit)"
