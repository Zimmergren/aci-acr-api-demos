using Microsoft.AspNetCore.Mvc;
using System.Net.Http;
using System.Net.Http.Headers;
using Newtonsoft.Json;

namespace TenantIDLookupAPI.Controllers
{
    [Route("api/")]
    [ApiController]
    public class TenantIDLookupController : ControllerBase
    {
        // GET api/tenantName without the suffix .onmicrosoft.com
        [HttpGet("{tenantName}")]
        public ActionResult<string> Get(string tenantName)
        {
            HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Accept.Clear();
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            // URL for querying tenantName
            var url = "https://login.windows.net/" + tenantName + ".onmicrosoft.com/v2.0/.well-known/openid-configuration";

            string tenantID = "";

            using (var response = client.GetAsync(url).Result)
            {
                if (response.IsSuccessStatusCode)
                {
                    var content = response.Content.ReadAsStringAsync().Result;
                    dynamic json = JsonConvert.DeserializeObject(content);
                    tenantID = json.authorization_endpoint;
                    tenantID = tenantID.Substring(26, 36);
                }
                else
                {
                    tenantID = "Error: " + response.StatusCode + ": " + response.ReasonPhrase;
                }
            }

            return tenantID;
        }
    }
}
