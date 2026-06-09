MRuby::Gem::Specification.new('mruby-redis') do |spec|
  spec.license = 'MIT'
  spec.authors = 'MATSUMOTO Ryosuke'
  spec.version = '0.0.1'
  # for expire test
  require 'open3'

  hiredis_dir = "#{build_dir}/hiredis"

  def run_command env, command
    STDOUT.sync = true
    puts "build: [exec] #{command}"
    Open3.popen2e(env, command) do |stdin, stdout, thread|
      print stdout.read
      fail "#{command} failed" if thread.value != 0
    end
  end

  FileUtils.mkdir_p build_dir

  # hiredis を安定版 tag に固定する。pin しないと master(HEAD) を取得するため、上流の
  # breaking change でビルドが壊れる (master の read.c が ffc.h を include し、未定義の
  # FFC_DEBUG マクロが -Werror=undef で fail する。ffc.h は v1.4.0 以降に同梱)。
  # macOS は従来どおり v0.13.3、それ以外は ffc.h 導入前の最新安定版 v1.3.0 に固定する。
  hiredis_tag = `uname` =~ /Darwin/ ? 'v0.13.3' : 'v1.3.0'

  if ! File.exist? hiredis_dir
    Dir.chdir(build_dir) do
      e = {}
      run_command e, 'git clone https://github.com/redis/hiredis.git'
      run_command e, "git --git-dir=#{hiredis_dir}/.git --work-tree=#{hiredis_dir} checkout #{hiredis_tag}"
    end
  end

  if ! File.exist? "#{hiredis_dir}/libhiredis.a"
    Dir.chdir hiredis_dir do
      e = {
        'CC' => "#{spec.build.cc.command} #{spec.build.cc.flags.reject {|flag| flag == '-fPIE'}.join(' ')}",
        'CXX' => "#{spec.build.cxx.command} #{spec.build.cxx.flags.join(' ')}",
        'LD' => "#{spec.build.linker.command} #{spec.build.linker.flags.join(' ')}",
        'AR' => spec.build.archiver.command,
        'PREFIX' => hiredis_dir
      }
      make_command = `uname` =~ /BSD/ ? "gmake" : "make"
      run_command e, "#{make_command}"
      run_command e, "#{make_command} install"
    end
  end

  spec.cc.include_paths << "#{hiredis_dir}/include"
  spec.linker.flags_before_libraries << "#{hiredis_dir}/lib/libhiredis.a"

  spec.add_dependency "mruby-sleep"
  spec.add_dependency "mruby-pointer", :github => 'matsumotory/mruby-pointer'
end
