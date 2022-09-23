using io.harness.cfsdk.client.api;
using Serilog;
using System;
using System.Net.Http;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Web;
using System.Web.Security;
using System.Web.SessionState;
using System.Threading.Tasks;
using io.harness.cfsdk.client.dto;

namespace DiegoFrameworkWebApplication
{
    public class Global : System.Web.HttpApplication
    {
        protected void Application_Start(object sender, EventArgs e)
        {
            Log.Logger = new LoggerConfiguration()
                .MinimumLevel.Debug()
                .WriteTo.Debug()
                .CreateLogger();
            Debug.WriteLine("Started");

            String apiKey = "8e9485c3-345a-41fe-a3ed-141649f2e562";

            HttpClient client = new HttpClient();
            System.Net.ServicePointManager.SecurityProtocol = System.Net.SecurityProtocolType.Tls12;
            /*try
            {
                //var task = Task.Run(() => client.GetAsync("http://www.contoso.com/"));
                var url = "https://config.ff.harness.io//api/1.0/client/auth";
                var jsonString = "{'apiKey':'8e9485c3-345a-41fe-a3ed-141649f2e562','target':{'identifier':'testdotnet'}'";
                var content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");

                var task = Task.Run(() => client.PostAsync(url, content));
                //var task = Task.Run(() => client.GetAsync("https://harness.io"));
                task.Wait();
                var response = task.Result;
                Debug.WriteLine(response);

                response.EnsureSuccessStatusCode();
                var readtask = Task.Run(() => response.Content.ReadAsStringAsync());
                readtask.Wait();
                var readresponse = task.Result;
                Debug.WriteLine(readresponse);


            }
            catch (HttpRequestException exc)
            {
                Console.WriteLine("\nException Caught!");
                Console.WriteLine("Message :{0} ", exc.Message);
            }*/


            // *********** SYNC USE ***********
            CfClient ffClient = new CfClient(apiKey, Config.Builder().Build());
            ffClient.InitializeAndWait().GetAwaiter().GetResult();

            ffClient.InitializationCompleted += (senderx, ex) =>
            {
                // fired when authentication is completed and recent configuration is fetched from server
                Debug.WriteLine("Notification Initialization Completed");
            };
            ffClient.EvaluationChanged += (sendery, identifier) =>
            {
                // Fired when flag value changes.
                Debug.WriteLine($"Flag changed for {identifier}");
            };

            Target target = Target.builder()
                            .Name("Harness_Target_1")
                            .Identifier("Harness_1")
                            .Attributes(new Dictionary<string, string>() { { "email", "demo@harness.io" } })
                            .build();
            CfClient.Instance.boolVariation("flag_name", target, false);


            // *********** ASYNC USE ***********

            //CfClient.Instance.Initialize(apiKey, Config.Builder().Build());
            //CfClient.Instance.InitializationCompleted += (senderx, ex) =>
            //{
            //    // fired when authentication is completed and recent configuration is fetched from server
            //    Debug.WriteLine("Notification Initialization Completed");
            //};
            //CfClient.Instance.EvaluationChanged += (sendery, identifier) =>
            //{
            //    // Fired when flag value changes.
            //    Debug.WriteLine($"Flag changed for {identifier}");
            //};
        }
    }
}