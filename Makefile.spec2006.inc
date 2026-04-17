spec2006_srcdir := $(benchdir)/spec2006
spec2006_cfg_template := $(spec2006_srcdir)/config/SigRISCV-freebsd-clang.cfg.in
spec2006_wrkdir := $(wrkdir)/spec2006
spec2006_cfg := $(spec2006_wrkdir)/sigriscv-$(MODE).cfg
spec2006_ext := sigriscv-$(MODE)
spec2006_bench_root := $(freebsd_bench)/spec2006

spec2006_mcf_srcdir := $(spec2006_srcdir)/benchspec/CPU2006/429.mcf
spec2006_mcf_exe := $(spec2006_mcf_srcdir)/exe/mcf_base.$(spec2006_ext)
spec2006_mcf_install := $(spec2006_bench_root)/429.mcf
spec2006_mcf_script_src := $(spec2006_srcdir)/scripts/run_mcf.sh
spec2006_mcf_install_exe := $(spec2006_mcf_install)/$(MODE)_mcf
spec2006_mcf_install_script := $(spec2006_mcf_install)/$(MODE)_run_mcf.sh
spec2006_mcf_install_cfg := $(spec2006_mcf_install)/$(MODE)_spec2006.cfg

spec2006_libquantum_srcdir := $(spec2006_srcdir)/benchspec/CPU2006/462.libquantum
spec2006_libquantum_exe := $(spec2006_libquantum_srcdir)/exe/libquantum_base.$(spec2006_ext)
spec2006_libquantum_install := $(spec2006_bench_root)/462.libquantum
spec2006_libquantum_script_src := $(spec2006_srcdir)/scripts/run_libquantum.sh
spec2006_libquantum_install_exe := $(spec2006_libquantum_install)/$(MODE)_libquantum
spec2006_libquantum_install_script := $(spec2006_libquantum_install)/$(MODE)_run_libquantum.sh
spec2006_libquantum_install_cfg := $(spec2006_libquantum_install)/$(MODE)_spec2006.cfg

spec2006_bzip2_srcdir := $(spec2006_srcdir)/benchspec/CPU2006/401.bzip2
spec2006_bzip2_exe := $(spec2006_bzip2_srcdir)/exe/bzip2_base.$(spec2006_ext)
spec2006_bzip2_install := $(spec2006_bench_root)/401.bzip2
spec2006_bzip2_script_src := $(spec2006_srcdir)/scripts/run_bzip2.sh
spec2006_bzip2_install_exe := $(spec2006_bzip2_install)/$(MODE)_bzip2
spec2006_bzip2_install_script := $(spec2006_bzip2_install)/$(MODE)_run_bzip2.sh
spec2006_bzip2_install_cfg := $(spec2006_bzip2_install)/$(MODE)_spec2006.cfg

spec2006_lbm_srcdir := $(spec2006_srcdir)/benchspec/CPU2006/470.lbm
spec2006_lbm_exe := $(spec2006_lbm_srcdir)/exe/lbm_base.$(spec2006_ext)
spec2006_lbm_install := $(spec2006_bench_root)/470.lbm
spec2006_lbm_script_src := $(spec2006_srcdir)/scripts/run_lbm.sh
spec2006_lbm_install_exe := $(spec2006_lbm_install)/$(MODE)_lbm
spec2006_lbm_install_script := $(spec2006_lbm_install)/$(MODE)_run_lbm.sh
spec2006_lbm_install_cfg := $(spec2006_lbm_install)/$(MODE)_spec2006.cfg

spec2006_sjeng_srcdir := $(spec2006_srcdir)/benchspec/CPU2006/458.sjeng
spec2006_sjeng_exe := $(spec2006_sjeng_srcdir)/exe/sjeng_base.$(spec2006_ext)
spec2006_sjeng_install := $(spec2006_bench_root)/458.sjeng
spec2006_sjeng_script_src := $(spec2006_srcdir)/scripts/run_sjeng.sh
spec2006_sjeng_install_exe := $(spec2006_sjeng_install)/$(MODE)_sjeng
spec2006_sjeng_install_script := $(spec2006_sjeng_install)/$(MODE)_run_sjeng.sh
spec2006_sjeng_install_cfg := $(spec2006_sjeng_install)/$(MODE)_spec2006.cfg

$(spec2006_cfg): $(spec2006_cfg_template)
	mkdir -p $(spec2006_wrkdir)
	sed \
		-e 's|@EXT@|$(spec2006_ext)|g' \
		-e 's|@NPROC@|$(shell nproc)|g' \
		-e 's|@CC@|$(toolchain_dest)/bin/clang|g' \
		-e 's|@CXX@|$(toolchain_dest)/bin/clang++|g' \
		-e 's|@EXTRA_CFLAGS@|$(LLVM_CROSS_CFLAGS_NOWARN)|g' \
		-e 's|@COPTIMIZE@|-O1 -g|g' \
		-e 's|@EXTRA_LDFLAGS@|$(LLVM_CROSS_LDFLAGS)|g' \
		$< > $@

define spec2006_install_rule
.PHONY: $(1)
$(1): $(spec2006_cfg)
	cd $(spec2006_srcdir) && . ./shrc && bin/relocate && runspec --config=$(spec2006_cfg) --action=build --tune=base --loose $(2)
	mkdir -p $(3)
	mkdir -p $(3)/src
	rm -rf $(3)/raw $(3)/sig
	cp $(4) $(5)
	cp $(6) $(7)
	chmod +x $(7)
	cp $(spec2006_cfg) $(8)
	if [ -d $(9)/Docs ]; then mkdir -p $(3)/Docs && cp -r $(9)/Docs/. $(3)/Docs/; fi
	cp $(9)/src/* $(3)/src/
	rm -rf $(3)/data
	cp -r $(9)/data $(3)/
endef

$(eval $(call spec2006_install_rule,spec2006-mcf,429.mcf,$(spec2006_mcf_install),$(spec2006_mcf_exe),$(spec2006_mcf_install_exe),$(spec2006_mcf_script_src),$(spec2006_mcf_install_script),$(spec2006_mcf_install_cfg),$(spec2006_mcf_srcdir)))
$(eval $(call spec2006_install_rule,spec2006-libquantum,462.libquantum,$(spec2006_libquantum_install),$(spec2006_libquantum_exe),$(spec2006_libquantum_install_exe),$(spec2006_libquantum_script_src),$(spec2006_libquantum_install_script),$(spec2006_libquantum_install_cfg),$(spec2006_libquantum_srcdir)))
$(eval $(call spec2006_install_rule,spec2006-bzip2,401.bzip2,$(spec2006_bzip2_install),$(spec2006_bzip2_exe),$(spec2006_bzip2_install_exe),$(spec2006_bzip2_script_src),$(spec2006_bzip2_install_script),$(spec2006_bzip2_install_cfg),$(spec2006_bzip2_srcdir)))
$(eval $(call spec2006_install_rule,spec2006-lbm,470.lbm,$(spec2006_lbm_install),$(spec2006_lbm_exe),$(spec2006_lbm_install_exe),$(spec2006_lbm_script_src),$(spec2006_lbm_install_script),$(spec2006_lbm_install_cfg),$(spec2006_lbm_srcdir)))
$(eval $(call spec2006_install_rule,spec2006-sjeng,458.sjeng,$(spec2006_sjeng_install),$(spec2006_sjeng_exe),$(spec2006_sjeng_install_exe),$(spec2006_sjeng_script_src),$(spec2006_sjeng_install_script),$(spec2006_sjeng_install_cfg),$(spec2006_sjeng_srcdir)))

.PHONY: spec2006
spec2006: spec2006-mcf spec2006-libquantum spec2006-bzip2 spec2006-lbm spec2006-sjeng
