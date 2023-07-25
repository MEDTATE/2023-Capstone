sp             := $(sp).x
dirstack_$(sp) := $(d)
d              := $(dir)


FILES:= \
	Utils.cpp \
	# empty line


DEPENDS_utils:=fmt
utils_SRC:=$(foreach f, $(FILES), $(dir)/$(f))


SRC_$(d):=$(addprefix $(d)/,$(FILES))


d  := $(dirstack_$(sp))
sp := $(basename $(sp))
