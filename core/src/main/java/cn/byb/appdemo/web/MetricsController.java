package cn.byb.appdemo.web;

import cn.byb.appdemo.biz.MetricsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class MetricsController {

    @Autowired
    private MetricsService metricsService;

    @RequestMapping("/metricTest")
    @ResponseBody
    String metricTest() {
        metricsService.executeRt();
        metricsService.executeTps();
        return "ok";
    }
}
