require 'fileutils'

class DbBackup::Uploaders::LocalFile

  def initialize(options = {})
    @path = options[:source].sub(%r{^file://}, '')

    if !::File.directory?(@path)
      DbBackup.logger.info("Creating folder #{@path}")
      FileUtils.mkdir_p(@path)
    end
  end

  def ls
    Dir.entries(@path).select do |file|
      file != "." && file != ".."
    end
  end

  def sync(local_folder, remote_path)
    DbBackup.logger.info("Creating folder #{::File.join(@path, remote_path)}")
    FileUtils.mkdir_p(::File.join(@path, remote_path))

    Dir.entries(local_folder).each do |file|
      next if file == "." || file == ".."
      target_path = ::File.join(@path, remote_path, file)
      DbBackup.logger.info("Copy #{file} to #{target_path}")
      FileUtils.cp_r(::File.join(local_folder, file), target_path, preserve: true)
    end
  end

  def rm_dirs(remote_paths)
    remote_paths.each do |path|
      DbBackup.logger.info("Deleting folder #{path}")
      FileUtils.rm_r(::File.join(@path, path))
    end
  end
end
