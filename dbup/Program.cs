using DbUp;
using DbUp.Engine;
using DbUp.Helpers;
using System;
using System.IO;
using System.Linq;
using System.Reflection;

namespace DbUpMigrator;

class Program
{
    static int Main(string[] args)
    {
        bool scriptsOnly = args.Contains("--scriptsonly");
        string outputFile = args.FirstOrDefault(a => a.StartsWith("--output="))?.Substring(9);
        string environment = args.FirstOrDefault(a => a.StartsWith("--environment="))?.Substring(14) ?? "dev";

        var connectionString = Environment.GetEnvironmentVariable("DB_CONNECTION_STRING");
        if (string.IsNullOrEmpty(connectionString))
        {
            Console.WriteLine("Error: Connection string not provided in DB_CONNECTION_STRING environment variable");
            return 1;
        }

        var upgradeEngineBuilder = DeployChanges.To
            .SqlDatabase(connectionString)
            .WithScriptsEmbeddedInAssembly(Assembly.GetExecutingAssembly())
            .JournalToSqlTable("dbo", "SchemaVersions")
            .WithTransaction() 
            .LogToConsole();

        if (scriptsOnly && !string.IsNullOrEmpty(outputFile))
        {
            var engine = upgradeEngineBuilder.Build();
            var script = engine.GenerateUpgradeHint();
            File.WriteAllText(outputFile, script);
            Console.WriteLine($"Generated migration script to: {outputFile}");
            return 0;
        }

        var upgrader = upgradeEngineBuilder.Build();

        if (!upgrader.IsUpgradeRequired())
        {
            Console.WriteLine("No database migrations needed");
            return 0;
        }

        var pendingScripts = upgrader.GetScriptsToExecute();
        Console.WriteLine($"The following migrations will be applied: {pendingScripts.Count()}");
        foreach (var script in pendingScripts)
        {
            Console.WriteLine($"- {script.Name}");
        }

        var result = upgrader.PerformUpgrade();

        if (!result.Successful)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.WriteLine($"Error during database migration: {result.Error}");
            Console.ResetColor();
            return -1;
        }

        Console.ForegroundColor = ConsoleColor.Green;
        Console.WriteLine("Database was upgraded.");
        Console.ResetColor();
        return 0;
    }
}
