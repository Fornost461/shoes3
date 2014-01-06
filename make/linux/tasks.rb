module Make
  include FileUtils

  def copy_files_to_dist
    cp_r  "fonts", "dist/fonts"
    cp   "lib/shoes.rb", "#{TGT_DIR}/lib"
    cp_r "lib/shoes", "#{TGT_DIR}/lib"
    cp_r  "samples", "dist/samples"
    cp_r  "static", "dist/static"
    cp    "README.md", "dist/README.txt"
    cp    "CHANGELOG", "dist/CHANGELOG.txt"
    cp    "COPYING", "dist/COPYING.txt"
  end

  def cc(t)
    sh "#{CC} -I. -c -o#{t.name} #{LINUX_CFLAGS} #{t.source}"
  end

  # Subs in special variables
  def rewrite before, after, reg = /\#\{(\w+)\}/, reg2 = '\1'
    File.open(after, 'w') do |a|
      File.open(before) do |b|
        b.each do |line|
          a << line.gsub(reg) do
            if reg2.include? '\1'
              reg2.gsub(%r!\\1!, Object.const_get($1))
            else
              reg2
            end
          end
        end
      end
    end
  end

  def copy_files glob, dir
    FileList[glob].each { |f| cp_r f, dir }
  end

  # does nothing. It could check if the dep libraries exist
  def pre_build
  end

  #  Build the extensions, gems and copy to Shoes directories
  def common_build
    puts "common_build dir=#{pwd} #{SHOES_RUBY_ARCH}"
    mkdir_p "#{TGT_DIR}/lib/ruby/#{RUBY_V}/#{SHOES_RUBY_ARCH}"
    #cp_r  "#{EXT_RUBY}/lib/ruby/#{RUBY_V}", "#{TGT_DIR}/ruby/lib"
    %w[req/ftsearch/lib/* req/rake/lib/*].each do |rdir|
      FileList[rdir].each { |rlib| cp_r rlib, "#{TGT_DIR}/lib/ruby/#{RUBY_V}" }
    end
    %w[req/ftsearch/ext/ftsearchrt req/chipmunk/ext/chipmunk].
    #%w[req/binject/ext/binject_c req/ftsearch/ext/ftsearchrt req/bloopsaphone/ext/bloops req/chipmunk/ext/chipmunk].
      each { |xdir| copy_ext xdir, "#{TGT_DIR}/lib/ruby/#{RUBY_V}/#{SHOES_RUBY_ARCH}" }

    gdir = "#{TGT_DIR}/lib/ruby/gems/#{RUBY_V}"
    {}.each do |gemn, xdir|
    #{'hpricot' => 'lib', 'json' => 'lib/json/ext', 'sqlite3' => 'lib'}.each do |gemn, xdir|
      spec = eval(File.read("req/#{gemn}/gemspec"))
      mkdir_p "#{gdir}/specifications"
      mkdir_p "#{gdir}/gems/#{spec.full_name}/lib"
      FileList["req/#{gemn}/lib/*"].each { |rlib| cp_r rlib, "#{gdir}/gems/#{spec.full_name}/lib" }
      mkdir_p "#{gdir}/gems/#{spec.full_name}/#{xdir}"
      FileList["req/#{gemn}/ext/*"].each { |elib| copy_ext elib, "#{gdir}/gems/#{spec.full_name}/#{xdir}" }
      cp "req/#{gemn}/gemspec", "#{gdir}/specifications/#{spec.full_name}.gemspec"
    end
  end

  # Check the environment
  def env(x)
    unless ENV[x]
      abort "Your #{x} environment variable is not set!"
    end
    ENV[x]
  end
end


include FileUtils

class MakeLinux
  extend Make

  class << self
    def copy_ext xdir, libdir
      Dir.chdir(xdir) do
        unless system "ruby", "extconf.rb" and system "make"
          raise "Extension build failed"
        end
      end
      copy_files "#{xdir}/*.so", libdir
    end

    def find_and_copy thelib, newplace
        testpath = ["/usr/lib/#{thelib}", "/usr/lib/x86_64-linux-gnu/#{thelib}",
          "/usr/lib/i386-linux-gnu/#{thelib}"]
        testpath.each do |tp|
          if File.exists? tp
            cp tp, newplace
            return
          end
        end
    end

    # does nothing
    def copy_deps_to_dist
      #pre_build task copied this
      #cp    "#{::EXT_RUBY}/lib/lib#{::RUBY_SO}.so", "dist/lib#{::RUBY_SO}.so"
      #ln_s  "lib#{::RUBY_SO}.so", "dist/lib#{::RUBY_SO}.so.#{::RUBY_V[/^\d+\.\d+/]}"
      #cp    "/usr/lib/libgif.so", "dist/libgif.so.4"
      #ln_s  "libgif.so.4", "dist/libungif.so.4"
      #cp    "/usr/lib/libungif.so", "dist/libungif.so.4"
      #find_and_copy "libgif.so", "dist/libungif.so.4"
      #find_and_copy "libjpeg.so", "dist/libjpeg.so.8"
      #find_and_copy "libcurl.so", "dist/libcurl.so.4"
      #find_and_copy "libportaudio.so", "dist/libportaudio.so.2"
      #find_and_copy  "libsqlite3.so", "dist/libsqlite3.so.0"
      #sh    "strip -x dist/*.so.*"
      #sh    "strip -x dist/*.so"
    end

    def setup_system_resources
      cp APP['icons']['gtk'], "dist/static/app-icon.png"
    end
 
    def make_app(name)
      # name is dist/shoes
      rm_f name
      sh "#{CC} -o #{name} bin/main.o dist/shoes.a #{LINUX_LDFLAGS} #{LINUX_LIBS}" 
   end

    # make a static library 
    def make_so(name)
      puts "FIXME: #{name}"
      name = 'dist/shoes.a'
      sh "ar rc #{name} #{OBJ.join(' ')}"
      sh "ranlib #{name}"
    end

    def make_installer
      mkdir_p "pkg"
      sh "makeself dist pkg/#{PKG}.run '#{APPNAME}' ./#{NAME}"
    end
    
    def make_userinstall
      user = ENV['USER']
      home = ENV['HOME']
      hdir = "#{home}/.shoes/#{RELEASE_NAME}"
      mkdir_p hdir
      sh "cp -r dist/* #{hdir}"
      File.open("Shoes-loose.desktop",'w') do |f|
        f << "[Desktop Entry]\n"
        f << "Name=Shoes\n"
        f << "Exec=#{hdir}/dist/shoes\n"
        f << "StartupNotify=true\n"
        f << "Terminal=false\n"
        f << "Type=Application\n"
        f << "Icon=#{hdir}/dist/static/app-icon.png\n"
        f << "Categories=Programming\n"
      end
      puts "Please copy the 'Shoes-loose.desktop' to /usr/share/applications"
      puts "Or wherever your Linux desktop manager requires. You many need to sudo"
      puts "Edit the file if you like."
    end
  end
end