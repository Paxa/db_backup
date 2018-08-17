require 'shellwords'
require 'open3'

module DbBackup
  module CmdUtils
    def pipe_stream(from, to, buffer: nil, skip_piping: false)
      thread = Thread.new do
        begin
          while !from.closed? && char = from.readchar
            to.write(char) if !skip_piping
            buffer << char if buffer
          end
        rescue IOError => error
          #p error
        end
      end

      #thread.abort_on_exception = true
    end

    def record_stream(from, buffer: nil)
      pipe_stream(from, nil, buffer: buffer, skip_piping: true)
    end

    def cmd(command, *args)
      args = args.flatten

      env_vars = args.last.is_a?(Hash) ? args.pop : {}
      env_vars = env_vars.dup
      modified_env_vars = env_vars.dup

      ENV.each do |key, value|
        env_vars[key] ||= value
      end

      escaped_args = args.map do |arg|
        if arg && arg.to_s.start_with?("|", ">", "<", "&")
          arg.to_s
        else
          Shellwords.escape(arg)
        end
      end

      command = "#{command} #{escaped_args.join(" ")}".strip

      if verbose_logging?
        DbBackup.logger.info "RUN #{command.colorize(:green)}"
      end
      DbBackup.logger.debug "ENV #{DbBackup::LogUtil.hash(modified_env_vars)}" if modified_env_vars.size > 0

      stdout_str  = ""
      stderr_str  = ""
      exit_status = nil
      start_time  = Time.now.to_f

      Open3.popen3(env_vars, command) do |stdin, stdout, stderr, wait_thr|
        io_threads = []
        if DbBackup.verbose_logging?
          io_threads << pipe_stream(stdout, STDOUT, buffer: stdout_str)
          io_threads << pipe_stream(stderr, STDERR, buffer: stderr_str)
        else
          io_threads << record_stream(stdout, buffer: stdout_str)
          io_threads << record_stream(stderr, buffer: stderr_str)
        end

        exit_status = wait_thr.value

        io_threads.each(&:join)

        if exit_status != 0
          DbBackup.logger.warn "Process #{exit_status.pid} exit with code #{exit_status.exitstatus}"
        end
      end

      {
        exit_code: exit_status.exitstatus,
        pid: exit_status.pid,
        stdout: stdout_str,
        stderr: stderr_str,
        success: exit_status.success?,
        time: Time.now.to_f - start_time
      }
    end
  end
end
