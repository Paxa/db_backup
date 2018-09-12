require 'rexml/document'
require 'uri'

class DbBackup::Uploaders::WebDav

  def initialize(options = {})
    @http_url = options[:target]
    @prefix = URI.parse(options[:target]).path
    @prefix = "/"  if @prefix == ''
    @prefix += "/" if !@prefix.end_with?("/")
  end

  def ls
    res = req(:PROPFIND, @prefix, "-H", "Depth: 1")

    if res[:stdout] =~ /404 Not Found/
      return []
    end

    xml = res[:stdout]

    doc = REXML::Document.new(xml)
    links = doc.get_elements('//D:response/D:href').map(&:text)
    links.map {|l| l.sub(@prefix, '') }.select do |link|
      link != "" && link != ".DS_Store" && link !~ /\.DS_Store/
    end
  end

  def sync(local_folder, remote_path)
    target_path = ::File.join(@prefix, remote_path)
    created_folders = []

    DbBackup.logger.info("Creating remote folder #{@prefix}")
    req("MKCOL", "")

    Dir.chdir(local_folder) do
      Dir.glob("**/*").each do |file|
        next if !File.file?(file) || file == "." || file.end_with?("/.")

        file_dir = File.dirname(file)
        dirs = [target_path]
        file_dir.split("/").each do |dir|
          next if dir == "."
          dirs << [dirs.last, dir].compact.join("/")
        end

        dirs.each do |dir|
          if !created_folders.include?(dir)
            DbBackup.logger.info("Creating remote folder #{target_path}")
            req("MKCOL", dir)
            created_folders << dir
          end
        end

        remote_path = File.join(target_path, file)
        local_path = File.join(local_folder, file)

        DbBackup.logger.info("Uploading file #{file}")
        req("PUT", remote_path, "-T", local_path)
      end
    end
  end

  def rm_dirs(remote_paths)
    remote_paths.each do |remote_path|
      DbBackup.logger.info("Deleting remote folder #{remote_path}")
      req("DELETE", File.join(@prefix, remote_path))
    end
  end

  def req(method, path, *extras)
    path = URI.join(@http_url, path).to_s
    DbBackup.cmd("curl", "-X", method, *extras, path)
  end
end
