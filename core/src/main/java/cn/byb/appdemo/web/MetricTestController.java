package cn.byb.appdemo.web;

import cn.byb.appdemo.biz.MetricsDemo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class MetricTestController {

    @Autowired
    private MetricsDemo metricsDemo;

    @RequestMapping("/metricTest")
    @ResponseBody
    String metricTest() {
        metricsDemo.executeRt();
        metricsDemo.executeTps();
        return "ok";
    }
}
