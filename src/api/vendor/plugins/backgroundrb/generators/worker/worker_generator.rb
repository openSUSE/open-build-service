class WorkerGenerator < Rails::Generator::NamedBase
  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_path, class_name, "#{class_name}WorkerTest"

      # Worker and test directories.
      m.directory File.join('lib/workers', class_path)
      #m.directory File.join('test/unit', class_path)

      # Worker class and unit tests.
      m.template 'worker.rb',      File.join('lib/workers', class_path, "#{file_name}_worker.rb")
      #m.template 'unit_test.rb',  File.join('test/unit', class_path, "#{file_name}_worker_test.rb")
    end
  end
end
