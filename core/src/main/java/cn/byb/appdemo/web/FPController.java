package cn.byb.appdemo.web;

import cn.byb.appdemo.biz.FPService;
import cn.byb.appdemo.biz.MetricsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseBody;

@Controller
public class FPController {

    @Autowired
    private FPService fpService;

    @RequestMapping("/fpTest")
    @ResponseBody
    String metricTest() {
        return fpService.invoke();
    }
}
